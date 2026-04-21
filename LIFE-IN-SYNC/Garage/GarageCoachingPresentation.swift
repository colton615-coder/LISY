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
        stabilityScore: Int?
    ) -> GarageCoachingPresentation {
        let mode = renderMode(report: report, reliabilityStatus: reliabilityReport.status)
        let hero = makeHero(
            report: report,
            phase: selectedPhase,
            reliabilityReport: reliabilityReport,
            mode: mode
        )
        let snapshots = makeSnapshots(
            phase: selectedPhase,
            reliabilityReport: reliabilityReport,
            scorecard: scorecard,
            stabilityScore: stabilityScore
        )
        let metrics = makeMetrics(
            mode: mode,
            phase: selectedPhase,
            reliabilityReport: reliabilityReport,
            scorecard: scorecard,
            stabilityScore: stabilityScore
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
        mode: GarageCoachingRenderMode
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
            detailSections: detailSections
        )
    }

    private static func makeSnapshots(
        phase: SwingPhase,
        reliabilityReport: GarageReliabilityReport,
        scorecard: GarageSwingScorecard?,
        stabilityScore: Int?
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
            ]
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
            ]
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
            ]
        )

        return [scoreSnapshot, reliabilitySnapshot, phaseSnapshot]
    }

    private static func makeMetrics(
        mode: GarageCoachingRenderMode,
        phase: SwingPhase,
        reliabilityReport: GarageReliabilityReport,
        scorecard: GarageSwingScorecard?,
        stabilityScore: Int?
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
                    ]
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
                ]
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
                ]
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
                ]
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
                    ]
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
                    ]
                )
            )
        }

        return fallbackMetrics
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
