import Foundation

struct GarageSlowTempoLogic: Equatable {
    static let defaultAnchorBPM = 60.0
    static let defaultSubdivisionMultiplier = 2

    var anchorBPM = defaultAnchorBPM
    var subdivisionMultiplier = defaultSubdivisionMultiplier

    var subdivisionBPM: Double {
        anchorBPM * Double(subdivisionMultiplier)
    }

    var anchorInterval: TimeInterval {
        60 / max(anchorBPM, 1)
    }

    var subdivisionInterval: TimeInterval {
        anchorInterval / Double(max(subdivisionMultiplier, 1))
    }

    var swingDuration: TimeInterval {
        anchorInterval * 2
    }

    var topTimestamp: TimeInterval {
        anchorInterval
    }

    var impactTimestamp: TimeInterval {
        swingDuration
    }

    func topHoldDuration(for tempoRatio: ElasticSlingshotTempoRatio) -> TimeInterval {
        anchorInterval * tempoRatio.topHoldBeatFraction
    }

    func downswingDuration(for tempoRatio: ElasticSlingshotTempoRatio) -> TimeInterval {
        max(anchorInterval - topHoldDuration(for: tempoRatio), 0.05)
    }

    var tempoTitle: String {
        "\(Int(anchorBPM.rounded())) BPM Swing Tempo"
    }

    var trainingMapText: String {
        "Start → Top / Transition → Impact"
    }

    var subdivisionText: String {
        "Quiet \(Int(subdivisionBPM.rounded())) BPM guide ticks"
    }

    var primaryCue: String {
        "Feel the top. Do not rush down."
    }

    var landmarks: [GarageSlowTempoLandmark] {
        [
            GarageSlowTempoLandmark(
                beat: 1,
                title: "Start",
                cue: "Start calm.",
                isTransition: false
            ),
            GarageSlowTempoLandmark(
                beat: 2,
                title: "Top / Transition",
                cue: "Feel the top.",
                isTransition: true
            ),
            GarageSlowTempoLandmark(
                beat: 3,
                title: "Impact",
                cue: "Down first, then speed.",
                isTransition: false
            )
        ]
    }
}

struct GarageSlowTempoLandmark: Identifiable, Equatable {
    var id: Int { beat }
    let beat: Int
    let title: String
    let cue: String
    let isTransition: Bool
}
