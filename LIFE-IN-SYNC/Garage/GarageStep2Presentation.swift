import Foundation

struct GarageStep2ScorePresentation: Equatable {
    let title: String
    let subtitle: String
    let scoreValue: String
    let scoreLimit: String
}

struct GarageStep2MetricPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let grade: GarageMetricGrade
}

struct GarageStep2UnavailablePresentation: Equatable {
    let title: String
    let message: String
}

enum GarageStep2Presentation: Equatable {
    case ready(score: GarageStep2ScorePresentation, metrics: [GarageStep2MetricPresentation])
    case unavailable(GarageStep2UnavailablePresentation)

    static func make(scorecard: GarageSwingScorecard?) -> GarageStep2Presentation {
        guard let scorecard else {
            return .unavailable(
                GarageStep2UnavailablePresentation(
                    title: "Step 2 metrics unavailable",
                    message: GarageScorecardEngine.unavailableMessage
                )
            )
        }

        return .ready(
            score: GarageStep2ScorePresentation(
                title: "Swing Score",
                subtitle: "Five equally weighted DTL checks",
                scoreValue: String(scorecard.totalScore),
                scoreLimit: "/100"
            ),
            metrics: [
                metricPresentation(for: .tempo, in: scorecard),
                metricPresentation(for: .spine, in: scorecard),
                metricPresentation(for: .pelvis, in: scorecard),
                metricPresentation(for: .knee, in: scorecard),
                metricPresentation(for: .head, in: scorecard)
            ]
        )
    }

    private static func metricPresentation(
        for domain: GarageSwingDomain,
        in scorecard: GarageSwingScorecard
    ) -> GarageStep2MetricPresentation {
        let domainScore = scorecard.domainScores.first(where: { $0.id == domain.rawValue })
        let grade = domainScore?.grade ?? .needsWork

        let value: String
        switch domain {
        case .tempo:
            value = String(format: "%.1f : 1", scorecard.metrics.tempo.ratio)
        case .spine:
            value = String(format: "%.1f°", scorecard.metrics.spine.deltaDegrees)
        case .pelvis:
            value = String(format: "%.1f in", scorecard.metrics.pelvicDepth.driftInches)
        case .knee:
            value = String(
                format: "Left %.0f° / Right %.0f°",
                scorecard.metrics.kneeFlex.leftDeltaDegrees,
                scorecard.metrics.kneeFlex.rightDeltaDegrees
            )
        case .head:
            value = String(
                format: "Sway %.1f in · Dip %.1f in",
                scorecard.metrics.headStability.swayInches,
                scorecard.metrics.headStability.dipInches
            )
        }

        return GarageStep2MetricPresentation(
            id: domain.rawValue,
            title: title(for: domain),
            value: value,
            grade: grade
        )
    }

    private static func title(for domain: GarageSwingDomain) -> String {
        switch domain {
        case .tempo:
            "Tempo"
        case .spine:
            "Spine Delta"
        case .pelvis:
            "Pelvic Depth"
        case .knee:
            "Knee Flex"
        case .head:
            "Head Stability"
        }
    }
}
