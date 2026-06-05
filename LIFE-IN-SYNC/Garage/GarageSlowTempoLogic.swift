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
        "\(Int(anchorBPM.rounded())) BPM anchor"
    }

    var trainingMapText: String {
        "Start → Load → Impact"
    }

    var subdivisionText: String {
        "Quiet \(Int(subdivisionBPM.rounded())) BPM guide"
    }

    var primaryCue: String {
        "Load with patience. Release clean."
    }

    var landmarks: [GarageSlowTempoLandmark] {
        [
            GarageSlowTempoLandmark(
                beat: 1,
                title: "Start",
                cue: "Start the move.",
                isTransition: false
            ),
            GarageSlowTempoLandmark(
                beat: 2,
                title: "Load",
                cue: "Hold the load.",
                isTransition: true
            ),
            GarageSlowTempoLandmark(
                beat: 3,
                title: "Impact",
                cue: "Impact clean.",
                isTransition: false
            )
        ]
    }

    func visualState(elapsedTime: TimeInterval, isPlaying: Bool, recipe: ElasticSlingshotRecipe) -> GarageSlowTempoVisualState {
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

        let swingDuration = max(recipe.swingDuration(for: anchorBPM), 0.1)
        let cycleDuration = max(recipe.loopDuration(for: anchorBPM), swingDuration)
        let elapsedInCycle = elapsedTime.truncatingRemainder(dividingBy: cycleDuration)
        let impactWindow = min(max(recipe.restInterval * 0.18, 0.14), 0.26)
        let impactEndTimestamp = min(swingDuration + impactWindow, cycleDuration)
        let activeBeat: Int
        let nextIndex: Int
        let phaseLabel: String
        let phaseCue: String
        let isResting: Bool

        if elapsedInCycle < recipe.takeawayDuration(for: anchorBPM) {
            activeBeat = 1
            nextIndex = 1
            phaseLabel = landmarks[0].title
            phaseCue = landmarks[0].cue
            isResting = false
        } else if elapsedInCycle < swingDuration {
            activeBeat = 2
            nextIndex = 2
            phaseLabel = landmarks[1].title
            phaseCue = recipe.tempoRatio.feelLine
            isResting = false
        } else if elapsedInCycle < impactEndTimestamp {
            activeBeat = 3
            nextIndex = 0
            phaseLabel = landmarks[2].title
            phaseCue = landmarks[2].cue
            isResting = false
        } else {
            activeBeat = 3
            nextIndex = 0
            phaseLabel = "Reset"
            phaseCue = "Feel the next set."
            isResting = true
        }

        let activeLandmark = landmarks[max(min(activeBeat - 1, landmarks.count - 1), 0)]

        return GarageSlowTempoVisualState(
            elapsedInCycle: elapsedInCycle,
            cycleProgress: min(max(elapsedInCycle / swingDuration, 0), 1),
            activeBeat: activeBeat,
            activeLandmark: activeLandmark,
            nextLandmark: landmarks[nextIndex],
            phaseLabel: phaseLabel,
            phaseCue: phaseCue,
            isResting: isResting
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
