import SwiftUI

enum GarageCoachingRenderMode: String, Equatable {
    case ready
    case review
    case unavailable
    case provisional

    var signalMixHelperText: String {
        switch self {
        case .ready:
            "Deep-dive coaching cues"
        case .review:
            "Directional cues with review notes"
        case .unavailable:
            "Available evidence"
        case .provisional:
            "Reliability blockers"
        }
    }

    var disclaimerText: String {
        switch self {
        case .ready:
            "Use this as a cue, not a final judgment"
        case .review:
            "Use this directionally until the review notes are resolved"
        case .unavailable:
            "A primary coaching cue is not ready yet"
        case .provisional:
            "Trust is too low to coach from this swing yet"
        }
    }
}

enum GarageCoachingValueState: Equatable {
    case available
    case unavailable
}

enum GarageEvidenceEmphasis: Equatable {
    case coachingCue(String)
    case metric(String)
    case blocker(String)
}

enum GarageEvidenceReliabilityKind: Equatable {
    case lowPoseConfidence
    case missingKeyframeCoverage
    case reviewNotApproved
    case incompleteAnchorCoverage
    case unavailableReviewSource
    case manualAdjustmentLoad

    var label: String {
        switch self {
        case .lowPoseConfidence:
            "Pose Confidence"
        case .missingKeyframeCoverage:
            "Keyframe Coverage"
        case .reviewNotApproved:
            "Review Status"
        case .incompleteAnchorCoverage:
            "Grip Coverage"
        case .unavailableReviewSource:
            "Video Source"
        case .manualAdjustmentLoad:
            "Manual Adjustments"
        }
    }
}

enum GarageEvidenceTarget: Equatable {
    case checkpoint(
        frameIndex: Int,
        phase: SwingPhase,
        emphasis: GarageEvidenceEmphasis
    )
    case phaseWindow(
        startFrameIndex: Int,
        endFrameIndex: Int,
        selectedFrameIndex: Int,
        phase: SwingPhase,
        emphasis: GarageEvidenceEmphasis
    )
    case reliabilityIssue(
        kind: GarageEvidenceReliabilityKind,
        relatedFrameIndex: Int?,
        phase: SwingPhase?
    )
    case reviewNote(
        noteID: String,
        relatedFrameIndex: Int?,
        phase: SwingPhase?
    )

    var accessibilityLabel: String {
        switch self {
        case let .checkpoint(_, phase, emphasis):
            "\(emphasis.label) evidence at \(phase.reviewTitle)"
        case let .phaseWindow(_, _, _, phase, emphasis):
            "\(emphasis.label) directional evidence near \(phase.reviewTitle)"
        case let .reliabilityIssue(kind, _, _):
            "\(kind.label) evidence"
        case let .reviewNote(noteID, _, _):
            "\(noteID) evidence"
        }
    }

    var actionLabel: String {
        switch self {
        case .checkpoint:
            "View Evidence"
        case .phaseWindow:
            "View Sequence"
        case .reliabilityIssue:
            "Review Signal"
        case .reviewNote:
            "Review Note"
        }
    }
}

extension GarageEvidenceEmphasis {
    var label: String {
        switch self {
        case let .coachingCue(title), let .metric(title), let .blocker(title):
            title
        }
    }
}

struct GarageEvidenceContext: Equatable {
    let frames: [SwingFrame]
    let keyFrames: [KeyFrame]
    let syncFlow: GarageSyncFlowReport?
    let reviewFrameSource: GarageReviewFrameSourceState

    init(
        frames: [SwingFrame],
        keyFrames: [KeyFrame],
        syncFlow: GarageSyncFlowReport?,
        reviewFrameSource: GarageReviewFrameSourceState
    ) {
        self.frames = frames
        self.keyFrames = keyFrames
        self.syncFlow = syncFlow
        self.reviewFrameSource = reviewFrameSource
    }
}

enum GarageCoachingAccentStyle: Equatable {
    case accent
    case trusted
    case review
    case provisional
    case muted

    var tint: Color {
        switch self {
        case .accent:
            garageReviewAccent
        case .trusted:
            garageReviewApproved
        case .review:
            garageReviewPending
        case .provisional:
            garageReviewFlagged
        case .muted:
            garageReviewMutedText.opacity(0.72)
        }
    }
}

struct GarageCoachingDetailSection: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String

    init(id: String? = nil, title: String, body: String) {
        self.id = id ?? title.lowercased().replacingOccurrences(of: " ", with: "-")
        self.title = title
        self.body = body
    }
}

struct GarageCoachingHeroModel: Equatable {
    let headline: String
    let body: String
    let disclaimer: String
    let detailSections: [GarageCoachingDetailSection]
    var evidenceTarget: GarageEvidenceTarget? = nil
}

struct GarageCoachingSnapshotModel: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let caption: String
    let systemImage: String
    let accentStyle: GarageCoachingAccentStyle
    let valueState: GarageCoachingValueState
    let detailSections: [GarageCoachingDetailSection]
    var evidenceTarget: GarageEvidenceTarget? = nil
}

struct GarageCoachingMetricModel: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
    let badgeStyle: GarageCoachingBadgeStyle?
    let progress: Double?
    let valueState: GarageCoachingValueState
    let detailSections: [GarageCoachingDetailSection]
    var evidenceTarget: GarageEvidenceTarget? = nil

    var isPrimaryMetric: Bool {
        id == "reliability" || id == "score"
    }
}

struct GarageCoachingActionModel: Equatable {
    let title: String
    let body: String
    let notes: [String]
}

enum GarageCoachingBadgeStyle: Equatable {
    case trust(GarageReliabilityStatus)
    case performance(GarageCoachingMetricStatus)

    var title: String {
        switch self {
        case let .trust(status):
            status.rawValue.uppercased()
        case let .performance(status):
            status.label
        }
    }

    var tint: Color {
        switch self {
        case let .trust(status):
            status.tint
        case let .performance(status):
            status.tint
        }
    }
}

enum GarageCoachingDetailTarget: Identifiable, Equatable {
    case snapshot(GarageCoachingSnapshotModel)
    case metric(GarageCoachingMetricModel)

    var id: String {
        switch self {
        case let .snapshot(snapshot):
            "snapshot-\(snapshot.id)"
        case let .metric(metric):
            "metric-\(metric.id)"
        }
    }

    var title: String {
        switch self {
        case let .snapshot(snapshot):
            snapshot.title
        case let .metric(metric):
            metric.title
        }
    }

    var value: String {
        switch self {
        case let .snapshot(snapshot):
            snapshot.value
        case let .metric(metric):
            metric.value
        }
    }

    var caption: String {
        switch self {
        case let .snapshot(snapshot):
            return snapshot.caption
        case let .metric(metric):
            if let badgeStyle = metric.badgeStyle {
                return badgeStyle.title.capitalized
            }
            return metric.valueState == .available ? "available evidence" : "missing evidence"
        }
    }

    var systemImage: String {
        switch self {
        case let .snapshot(snapshot):
            snapshot.systemImage
        case let .metric(metric):
            metric.systemImage
        }
    }

    var accentTint: Color {
        switch self {
        case let .snapshot(snapshot):
            snapshot.accentStyle.tint
        case let .metric(metric):
            metric.badgeStyle?.tint ?? garageReviewMutedText.opacity(0.72)
        }
    }

    var detailSections: [GarageCoachingDetailSection] {
        switch self {
        case let .snapshot(snapshot):
            snapshot.detailSections
        case let .metric(metric):
            metric.detailSections
        }
    }
}

struct GarageCoachingPresentation: Equatable {
    let mode: GarageCoachingRenderMode
    let reliabilityStatus: GarageReliabilityStatus
    let phase: SwingPhase
    let hero: GarageCoachingHeroModel
    let snapshots: [GarageCoachingSnapshotModel]
    let metrics: [GarageCoachingMetricModel]
    let action: GarageCoachingActionModel
    let detailSections: [GarageCoachingDetailSection]

    var animationIdentityKey: String {
        [
            mode.rawValue,
            reliabilityStatus.rawValue,
            phase.rawValue,
            hero.headline,
            hero.body,
            hero.disclaimer,
            action.body,
            action.notes.joined(separator: "::"),
            snapshots.map { "\($0.id)|\($0.value)|\($0.caption)" }.joined(separator: "::"),
            metrics.map { "\($0.id)|\($0.value)|\($0.badgeStyle?.title ?? "none")" }.joined(separator: "::")
        ].joined(separator: "|")
    }

    static func make(
        report: GarageCoachingReport,
        selectedPhase: SwingPhase,
        reliabilityReport: GarageReliabilityReport,
        scorecard: GarageSwingScorecard?,
        stabilityScore: Int?,
        evidenceContext: GarageEvidenceContext? = nil
    ) -> GarageCoachingPresentation {
        let mode = renderMode(report: report, reliabilityStatus: reliabilityReport.status)
        let hero = makeHero(
            report: report,
            phase: selectedPhase,
            reliabilityReport: reliabilityReport,
            mode: mode,
            evidenceContext: evidenceContext
        )
        let snapshots = makeSnapshots(
            phase: selectedPhase,
            reliabilityReport: reliabilityReport,
            scorecard: scorecard,
            stabilityScore: stabilityScore,
            evidenceContext: evidenceContext
        )
        let metrics = makeMetrics(
            mode: mode,
            phase: selectedPhase,
            reliabilityReport: reliabilityReport,
            scorecard: scorecard,
            stabilityScore: stabilityScore,
            evidenceContext: evidenceContext
        )
        let notes = resolvedNotes(report: report, reliabilityReport: reliabilityReport)
        let action = GarageCoachingActionModel(
            title: "Next Best Action",
            body: report.nextBestAction,
            notes: notes
        )

        let detailSections = [
            GarageCoachingDetailSection(
                title: "Trust State",
                body: reliabilityReport.summary
            ),
            GarageCoachingDetailSection(
                title: "Focus Phase",
                body: "\(selectedPhase.reviewTitle) is the current coaching checkpoint on this swing."
            )
        ]

        return GarageCoachingPresentation(
            mode: mode,
            reliabilityStatus: reliabilityReport.status,
            phase: selectedPhase,
            hero: hero,
            snapshots: snapshots,
            metrics: metrics,
            action: action,
            detailSections: detailSections
        )
    }

    private static func renderMode(
        report: GarageCoachingReport,
        reliabilityStatus: GarageReliabilityStatus
    ) -> GarageCoachingRenderMode {
        if reliabilityStatus == .provisional {
            return .provisional
        }
        if report.cues.isEmpty {
            return .unavailable
        }
        if reliabilityStatus == .review {
            return .review
        }
        return .ready
    }

    private static func makeHero(
        report: GarageCoachingReport,
        phase: SwingPhase,
        reliabilityReport: GarageReliabilityReport,
        mode: GarageCoachingRenderMode,
        evidenceContext: GarageEvidenceContext?
    ) -> GarageCoachingHeroModel {
        let primaryCue = report.cues.first
        let rawHeadline = primaryCue?.title ?? report.headline
        let headline = formattedHeadline(from: rawHeadline)

        let body: String
        switch mode {
        case .ready, .review:
            body = primaryCue?.message ?? report.nextBestAction
        case .unavailable:
            body = report.blockers.first
                ?? "Review the motion and available evidence while coaching catches up."
        case .provisional:
            body = report.blockers.first
                ?? "Fix the failed reliability checks before using coaching cues."
        }

        let detailSections = [
            GarageCoachingDetailSection(
                title: "Confidence",
                body: reliabilityReport.summary
            ),
            GarageCoachingDetailSection(
                title: "Focus",
                body: "\(phase.reviewTitle) is the current focus checkpoint for this deep dive."
            )
        ]

        return GarageCoachingHeroModel(
            headline: mode == .unavailable ? "Coaching unavailable" : headline,
            body: body,
            disclaimer: mode.disclaimerText,
            detailSections: detailSections,
            evidenceTarget: evidenceTarget(
                for: primaryCue,
                fallbackPhase: phase,
                reliabilityStatus: reliabilityReport.status,
                context: evidenceContext
            )
        )
    }

    private static func makeSnapshots(
        phase: SwingPhase,
        reliabilityReport: GarageReliabilityReport,
        scorecard: GarageSwingScorecard?,
        stabilityScore: Int?,
        evidenceContext: GarageEvidenceContext?
    ) -> [GarageCoachingSnapshotModel] {
        let scoreSnapshot = GarageCoachingSnapshotModel(
            id: "score",
            title: "Session Analysis",
            value: scorecard.map { "\($0.totalScore)" } ?? "UNAVAILABLE",
            caption: scorecard == nil ? "scorecard pending" : "swing score",
            systemImage: scorecard == nil ? "chart.bar.xaxis" : "waveform.path.ecg.rectangle",
            accentStyle: scorecard == nil ? .muted : .accent,
            valueState: scorecard == nil ? .unavailable : .available,
            detailSections: [
                GarageCoachingDetailSection(
                    title: "Scorecard",
                    body: scorecard == nil
                        ? "The Step 2 scorecard is not available for this swing yet, so the session score cannot be shown."
                        : "The session score is the current total from the DTL domain scorecard."
                )
            ],
            evidenceTarget: scorecard == nil ? nil : phaseWindowEvidence(
                startPhase: .address,
                endPhase: .impact,
                selectedPhase: phase,
                emphasis: .metric("Session Analysis"),
                context: evidenceContext
            )
        )

        let failedCheckDetails = reliabilityReport.checks
            .filter { $0.passed == false }
            .map(\.detail)
        let reliabilitySnapshot = GarageCoachingSnapshotModel(
            id: "reliability",
            title: "Reliability",
            value: reliabilityReport.status.rawValue.uppercased(),
            caption: "signal confidence",
            systemImage: reliabilityReport.status.systemImage,
            accentStyle: accentStyle(for: reliabilityReport.status),
            valueState: .available,
            detailSections: [
                GarageCoachingDetailSection(
                    title: "Summary",
                    body: reliabilityReport.summary
                ),
                GarageCoachingDetailSection(
                    title: failedCheckDetails.isEmpty ? "Status" : "Needs Review",
                    body: failedCheckDetails.first ?? "All current reliability checks are passing."
                )
            ],
            evidenceTarget: reliabilityEvidenceTarget(
                reliabilityReport: reliabilityReport,
                selectedPhase: phase,
                context: evidenceContext
            )
        )

        let phaseSnapshot = GarageCoachingSnapshotModel(
            id: "phase",
            title: "Focus Phase",
            value: phase.reviewTitle,
            caption: stabilityScore.map { "stability \($0)" } ?? "stability unavailable",
            systemImage: "figure.golf",
            accentStyle: .accent,
            valueState: .available,
            detailSections: [
                GarageCoachingDetailSection(
                    title: "Checkpoint",
                    body: "\(phase.reviewTitle) is the active checkpoint for the current coaching summary."
                ),
                GarageCoachingDetailSection(
                    title: "Stability",
                    body: stabilityScore.map {
                        "Postural stability is currently \($0), based on head and pelvis drift from setup to impact."
                    } ?? "Postural stability could not be calculated from the current swing data."
                )
            ],
            evidenceTarget: checkpointEvidence(
                phase: phase,
                emphasis: .metric("Focus Phase"),
                context: evidenceContext
            )
        )

        return [scoreSnapshot, reliabilitySnapshot, phaseSnapshot]
    }

    private static func makeMetrics(
        mode: GarageCoachingRenderMode,
        phase: SwingPhase,
        reliabilityReport: GarageReliabilityReport,
        scorecard: GarageSwingScorecard?,
        stabilityScore: Int?,
        evidenceContext: GarageEvidenceContext?
    ) -> [GarageCoachingMetricModel] {
        if let scorecard {
            let domainMetrics = GarageSwingDomain.allCases.compactMap { domain -> GarageCoachingMetricModel? in
                guard let domainScore = scorecard.domainScores.first(where: { $0.id == domain.rawValue }) else {
                    return nil
                }

                let status = GarageCoachingMetricStatus(from: domainScore.grade)
                return GarageCoachingMetricModel(
                    id: domain.rawValue,
                    title: coachingMetricTitle(for: domain),
                    value: domainScore.displayValue,
                    systemImage: coachingMetricIcon(for: domain),
                    badgeStyle: .performance(status),
                    progress: normalized(domainScore.score),
                    valueState: .available,
                    detailSections: [
                        GarageCoachingDetailSection(
                            title: domain.title,
                            body: "This tile is sourced from the current scorecard domain value: \(domainScore.displayValue)."
                        ),
                        GarageCoachingDetailSection(
                            title: "Grade",
                            body: "Current performance grade: \(domainScore.grade.label)."
                        )
                    ],
                    evidenceTarget: metricEvidenceTarget(
                        for: domain,
                        context: evidenceContext
                    )
                )
            }

            let reliabilityMetric = GarageCoachingMetricModel(
                id: "reliability",
                title: "Reliability",
                value: reliabilityReport.status.rawValue.uppercased(),
                systemImage: reliabilityReport.status.systemImage,
                badgeStyle: .trust(reliabilityReport.status),
                progress: normalized(reliabilityReport.status),
                valueState: .available,
                detailSections: [
                    GarageCoachingDetailSection(
                        title: "Reliability",
                        body: reliabilityReport.summary
                    ),
                    GarageCoachingDetailSection(
                        title: "Focus Phase",
                        body: "\(phase.reviewTitle) remains the active coaching checkpoint while trust is \(reliabilityReport.status.rawValue.lowercased())."
                    )
                ],
                evidenceTarget: reliabilityEvidenceTarget(
                    reliabilityReport: reliabilityReport,
                    selectedPhase: phase,
                    context: evidenceContext
                )
            )

            return Array((domainMetrics + [reliabilityMetric]).prefix(6))
        }

        var fallbackMetrics: [GarageCoachingMetricModel] = [
            GarageCoachingMetricModel(
                id: "score",
                title: "Session Score",
                value: "UNAVAILABLE",
                systemImage: "chart.bar.xaxis",
                badgeStyle: nil,
                progress: nil,
                valueState: .unavailable,
                detailSections: [
                    GarageCoachingDetailSection(
                        title: "Missing Scorecard",
                        body: "The Step 2 scorecard is not available yet, so the session score cannot be rendered."
                    )
                ],
                evidenceTarget: nil
            ),
            GarageCoachingMetricModel(
                id: "reliability",
                title: "Reliability",
                value: reliabilityReport.status.rawValue.uppercased(),
                systemImage: reliabilityReport.status.systemImage,
                badgeStyle: .trust(reliabilityReport.status),
                progress: normalized(reliabilityReport.status),
                valueState: .available,
                detailSections: [
                    GarageCoachingDetailSection(
                        title: "Reliability",
                        body: reliabilityReport.summary
                    )
                ],
                evidenceTarget: reliabilityEvidenceTarget(
                    reliabilityReport: reliabilityReport,
                    selectedPhase: phase,
                    context: evidenceContext
                )
            )
        ]

        if let stabilityScore {
            let status = metricStatus(for: stabilityScore)
            fallbackMetrics.append(
                GarageCoachingMetricModel(
                    id: "stability",
                    title: "Stability",
                    value: "\(stabilityScore)",
                    systemImage: "figure.walk",
                    badgeStyle: .performance(status),
                    progress: normalized(stabilityScore),
                    valueState: .available,
                    detailSections: [
                        GarageCoachingDetailSection(
                            title: "Support Metric",
                            body: "Stability is available even though the broader scorecard is missing."
                        )
                    ],
                    evidenceTarget: phaseWindowEvidence(
                        startPhase: .address,
                        endPhase: .impact,
                        selectedPhase: .impact,
                        emphasis: .metric("Stability"),
                        context: evidenceContext
                    )
                )
            )
        } else if mode == .provisional {
            fallbackMetrics.append(
                GarageCoachingMetricModel(
                    id: "stability",
                    title: "Stability",
                    value: "UNAVAILABLE",
                    systemImage: "figure.walk",
                    badgeStyle: nil,
                    progress: nil,
                    valueState: .unavailable,
                    detailSections: [
                        GarageCoachingDetailSection(
                            title: "Support Metric",
                            body: "Stability could not be calculated from the current swing data."
                        )
                    ],
                    evidenceTarget: nil
                )
            )
        }

        return fallbackMetrics
    }

    static func evidenceTarget(
        for cue: GarageCoachingCue?,
        fallbackPhase: SwingPhase,
        reliabilityStatus: GarageReliabilityStatus,
        context: GarageEvidenceContext?
    ) -> GarageEvidenceTarget? {
        guard let cue, let context else { return nil }

        if let syncIssue = context.syncFlow?.primaryIssue,
           cue.title == syncIssue.title || cue.message == syncIssue.detail {
            return syncFlowEvidenceTarget(
                for: syncIssue,
                reliabilityStatus: reliabilityStatus,
                context: context
            )
        }

        return checkpointEvidence(
            phase: fallbackPhase,
            emphasis: .coachingCue(cue.title),
            context: context
        )
    }

    private static func syncFlowEvidenceTarget(
        for issue: GarageSyncFlowIssue,
        reliabilityStatus: GarageReliabilityStatus,
        context: GarageEvidenceContext
    ) -> GarageEvidenceTarget? {
        guard supportsVisualEvidence(context) else { return nil }
        guard let selectedFrameIndex = nearestFrameIndex(to: issue.timestamp, in: context.frames) else {
            return nil
        }

        let phase = nearestPhase(for: selectedFrameIndex, keyFrames: context.keyFrames) ?? phase(for: issue.kind)
        let emphasis = GarageEvidenceEmphasis.coachingCue(issue.title)

        if reliabilityStatus == .trusted {
            return .checkpoint(
                frameIndex: selectedFrameIndex,
                phase: phase,
                emphasis: emphasis
            )
        }

        let window = frameWindow(
            around: selectedFrameIndex,
            lowerPadding: 3,
            upperPadding: 3,
            frameCount: context.frames.count
        )
        return .phaseWindow(
            startFrameIndex: window.lowerBound,
            endFrameIndex: window.upperBound,
            selectedFrameIndex: selectedFrameIndex,
            phase: phase,
            emphasis: emphasis
        )
    }

    private static func metricEvidenceTarget(
        for domain: GarageSwingDomain,
        context: GarageEvidenceContext?
    ) -> GarageEvidenceTarget? {
        switch domain {
        case .tempo:
            return phaseWindowEvidence(
                startPhase: .topOfBackswing,
                endPhase: .impact,
                selectedPhase: .transition,
                emphasis: .metric("Tempo"),
                context: context
            )
        case .spine:
            return phaseWindowEvidence(
                startPhase: .address,
                endPhase: .impact,
                selectedPhase: .impact,
                emphasis: .metric("Spine"),
                context: context
            )
        case .pelvis:
            return phaseWindowEvidence(
                startPhase: .transition,
                endPhase: .impact,
                selectedPhase: .earlyDownswing,
                emphasis: .metric("Pelvis"),
                context: context
            )
        case .knee:
            return phaseWindowEvidence(
                startPhase: .address,
                endPhase: .impact,
                selectedPhase: .impact,
                emphasis: .metric("Knees"),
                context: context
            )
        case .head:
            return phaseWindowEvidence(
                startPhase: .address,
                endPhase: .impact,
                selectedPhase: .impact,
                emphasis: .metric("Head"),
                context: context
            )
        }
    }

    private static func reliabilityEvidenceTarget(
        reliabilityReport: GarageReliabilityReport,
        selectedPhase: SwingPhase,
        context: GarageEvidenceContext?
    ) -> GarageEvidenceTarget? {
        guard let context else { return nil }

        if let failedCheck = reliabilityReport.checks.first(where: { $0.passed == false }) {
            let kind = reliabilityKind(for: failedCheck)
            let relatedPhase = relatedPhase(for: kind, selectedPhase: selectedPhase)
            let relatedIndex = relatedPhase.flatMap {
                frameIndex(for: $0, keyFrames: context.keyFrames)
            }

            return .reliabilityIssue(
                kind: kind,
                relatedFrameIndex: relatedIndex,
                phase: relatedPhase
            )
        }

        return phaseWindowEvidence(
            startPhase: .address,
            endPhase: .impact,
            selectedPhase: selectedPhase,
            emphasis: .blocker("Trusted signal"),
            context: context
        )
    }

    private static func checkpointEvidence(
        phase: SwingPhase,
        emphasis: GarageEvidenceEmphasis,
        context: GarageEvidenceContext?
    ) -> GarageEvidenceTarget? {
        guard
            let context,
            supportsVisualEvidence(context),
            let frameIndex = frameIndex(for: phase, keyFrames: context.keyFrames)
        else {
            return nil
        }

        return .checkpoint(frameIndex: frameIndex, phase: phase, emphasis: emphasis)
    }

    private static func phaseWindowEvidence(
        startPhase: SwingPhase,
        endPhase: SwingPhase,
        selectedPhase: SwingPhase,
        emphasis: GarageEvidenceEmphasis,
        context: GarageEvidenceContext?
    ) -> GarageEvidenceTarget? {
        guard
            let context,
            supportsVisualEvidence(context),
            let startIndex = frameIndex(for: startPhase, keyFrames: context.keyFrames),
            let endIndex = frameIndex(for: endPhase, keyFrames: context.keyFrames)
        else {
            return nil
        }

        let lowerBound = min(startIndex, endIndex)
        let upperBound = max(startIndex, endIndex)
        let selectedIndex = frameIndex(for: selectedPhase, keyFrames: context.keyFrames)
            .map { min(max($0, lowerBound), upperBound) }
            ?? lowerBound + ((upperBound - lowerBound) / 2)

        return .phaseWindow(
            startFrameIndex: lowerBound,
            endFrameIndex: upperBound,
            selectedFrameIndex: selectedIndex,
            phase: selectedPhase,
            emphasis: emphasis
        )
    }

    private static func supportsVisualEvidence(_ context: GarageEvidenceContext) -> Bool {
        context.reviewFrameSource != .recoveryNeeded && context.frames.isEmpty == false
    }

    private static func frameIndex(for phase: SwingPhase, keyFrames: [KeyFrame]) -> Int? {
        keyFrames.first(where: { $0.phase == phase })?.frameIndex
    }

    private static func nearestFrameIndex(to timestamp: Double, in frames: [SwingFrame]) -> Int? {
        guard frames.isEmpty == false else { return nil }

        return frames.enumerated().min { lhs, rhs in
            abs(lhs.element.timestamp - timestamp) < abs(rhs.element.timestamp - timestamp)
        }?.offset
    }

    private static func nearestPhase(for frameIndex: Int, keyFrames: [KeyFrame]) -> SwingPhase? {
        keyFrames.min { lhs, rhs in
            abs(lhs.frameIndex - frameIndex) < abs(rhs.frameIndex - frameIndex)
        }?.phase
    }

    private static func frameWindow(
        around selectedFrameIndex: Int,
        lowerPadding: Int,
        upperPadding: Int,
        frameCount: Int
    ) -> ClosedRange<Int> {
        let lastIndex = max(frameCount - 1, 0)
        let start = min(max(selectedFrameIndex - lowerPadding, 0), lastIndex)
        let end = min(max(selectedFrameIndex + upperPadding, 0), lastIndex)
        return min(start, end)...max(start, end)
    }

    private static func phase(for issueKind: GarageSyncFlowIssueKind) -> SwingPhase {
        switch issueKind {
        case .earlyHands:
            .transition
        case .hipStall:
            .earlyDownswing
        case .earlyExtension, .unstableHead:
            .impact
        }
    }

    private static func reliabilityKind(for check: GarageReliabilityCheck) -> GarageEvidenceReliabilityKind {
        switch check.title {
        case "Video Source":
            .unavailableReviewSource
        case "Keyframe Coverage":
            .missingKeyframeCoverage
        case "Review Status":
            .reviewNotApproved
        case "Grip Coverage":
            .incompleteAnchorCoverage
        case "Pose Confidence":
            .lowPoseConfidence
        case "Manual Adjustments":
            .manualAdjustmentLoad
        default:
            .reviewNotApproved
        }
    }

    private static func relatedPhase(
        for kind: GarageEvidenceReliabilityKind,
        selectedPhase: SwingPhase
    ) -> SwingPhase? {
        switch kind {
        case .lowPoseConfidence, .reviewNotApproved, .manualAdjustmentLoad:
            selectedPhase
        case .missingKeyframeCoverage, .incompleteAnchorCoverage:
            selectedPhase
        case .unavailableReviewSource:
            nil
        }
    }

    private static func resolvedNotes(
        report: GarageCoachingReport,
        reliabilityReport: GarageReliabilityReport
    ) -> [String] {
        let reportNotes = Array(report.blockers.prefix(2))
        if reportNotes.isEmpty == false {
            return reportNotes
        }

        return Array(
            reliabilityReport.checks
                .filter { $0.passed == false }
                .map(\.detail)
                .prefix(2)
        )
    }

    private static func formattedHeadline(from rawHeadline: String) -> String {
        switch rawHeadline {
        case "Transition Looks Rushed":
            "Transition appears faster than this swing's baseline"
        default:
            rawHeadline
        }
    }

    private static func coachingMetricTitle(for domain: GarageSwingDomain) -> String {
        switch domain {
        case .tempo:
            "Tempo"
        case .spine:
            "Spine"
        case .pelvis:
            "Pelvis"
        case .knee:
            "Knees"
        case .head:
            "Head"
        }
    }

    private static func coachingMetricIcon(for domain: GarageSwingDomain) -> String {
        switch domain {
        case .tempo:
            "metronome"
        case .spine:
            "angle"
        case .pelvis:
            "arrow.left.and.right"
        case .knee:
            "figure.walk"
        case .head:
            "viewfinder.circle"
        }
    }

    private static func metricStatus(for score: Int) -> GarageCoachingMetricStatus {
        switch score {
        case 85...:
            .great
        case 70..<85:
            .good
        case 55..<70:
            .watch
        default:
            .bad
        }
    }

    private static func normalized(_ score: Int) -> Double {
        min(max(Double(score) / 100, 0), 1)
    }

    private static func normalized(_ reliabilityStatus: GarageReliabilityStatus) -> Double {
        switch reliabilityStatus {
        case .trusted:
            0.92
        case .review:
            0.68
        case .provisional:
            0.34
        }
    }

    private static func accentStyle(for reliabilityStatus: GarageReliabilityStatus) -> GarageCoachingAccentStyle {
        switch reliabilityStatus {
        case .trusted:
            .trusted
        case .review:
            .review
        case .provisional:
            .provisional
        }
    }
}

enum GarageCoachingMetricStatus: String, Equatable {
    case great
    case good
    case watch
    case bad

    init(from grade: GarageMetricGrade) {
        switch grade {
        case .excellent:
            self = .great
        case .good:
            self = .good
        case .fair:
            self = .watch
        case .needsWork:
            self = .bad
        }
    }

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

extension GarageReliabilityStatus {
    var tint: Color {
        switch self {
        case .trusted:
            garageReviewApproved
        case .review:
            garageReviewPending
        case .provisional:
            garageReviewFlagged
        }
    }

    var systemImage: String {
        switch self {
        case .trusted:
            "checkmark.shield"
        case .review:
            "exclamationmark.shield"
        case .provisional:
            "shield.slash"
        }
    }
}
