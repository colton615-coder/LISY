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

    func visualState(elapsedTime: TimeInterval, isPlaying: Bool) -> GarageSlowTempoVisualState {
        guard isPlaying else {
            return GarageSlowTempoVisualState(
                elapsedInCycle: 0,
                cycleProgress: 0,
                activeBeat: 1,
                activeLandmark: landmarks[0],
                nextLandmark: landmarks[1],
                phaseLabel: "Ready",
                phaseCue: primaryCue,
                isResting: false
            )
        }

        let cycleDuration = max(swingDuration, 0.1)
        let elapsedInCycle = elapsedTime.truncatingRemainder(dividingBy: cycleDuration)
        let activeBeat: Int
        let nextIndex: Int

        if elapsedInCycle < topTimestamp {
            activeBeat = 1
            nextIndex = 1
        } else if elapsedInCycle < impactTimestamp {
            activeBeat = 2
            nextIndex = 2
        } else {
            activeBeat = 3
            nextIndex = 0
        }

        let activeLandmark = landmarks[max(min(activeBeat - 1, landmarks.count - 1), 0)]

        return GarageSlowTempoVisualState(
            elapsedInCycle: elapsedInCycle,
            cycleProgress: min(max(elapsedInCycle / cycleDuration, 0), 1),
            activeBeat: activeBeat,
            activeLandmark: activeLandmark,
            nextLandmark: landmarks[nextIndex],
            phaseLabel: activeLandmark.title,
            phaseCue: activeLandmark.cue,
            isResting: false
        )
    }
}

struct GarageSlowTempoLandmark: Identifiable, Equatable {
    var id: Int { beat }
    let beat: Int
    let title: String
    let cue: String
    let isTransition: Bool
}

struct GarageSlowTempoVisualState: Equatable {
    let elapsedInCycle: TimeInterval
    let cycleProgress: Double
    let activeBeat: Int
    let activeLandmark: GarageSlowTempoLandmark
    let nextLandmark: GarageSlowTempoLandmark
    let phaseLabel: String
    let phaseCue: String
    let isResting: Bool
}
