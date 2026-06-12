import Foundation

struct GarageSlowTempoLogic: Equatable {
    static let defaultAnchorBPM = 60.0
    static let defaultSubdivisionMultiplier = 2
    static let consumerBPMRange = 20.0...75.0

    static func clampedConsumerBPM(_ beatsPerMinute: Double) -> Double {
        min(max(beatsPerMinute, consumerBPMRange.lowerBound), consumerBPMRange.upperBound)
    }

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
                isResting: false,
                motionProgress: 0
            )
        }

        let swingDuration = max(recipe.swingDuration(for: anchorBPM), 0.1)
        let cycleDuration = max(recipe.loopDuration(for: anchorBPM), swingDuration)
        let elapsedInCycle = elapsedTime.truncatingRemainder(dividingBy: cycleDuration)
        let impactEndTimestamp = swingDuration + recipe.impactDuration
        let followThroughEndTimestamp = impactEndTimestamp + recipe.followThroughDuration
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
        } else if elapsedInCycle < followThroughEndTimestamp {
            activeBeat = 3
            nextIndex = 0
            phaseLabel = elapsedInCycle < impactEndTimestamp ? landmarks[2].title : "Follow Through"
            phaseCue = elapsedInCycle < impactEndTimestamp ? landmarks[2].cue : "Finish balanced."
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
            isResting: isResting,
            motionProgress: motionProgress(
                elapsedTime: elapsedInCycle,
                recipe: recipe
            )
        )
    }

    private func motionProgress(elapsedTime: TimeInterval, recipe: ElasticSlingshotRecipe) -> Double {
        let takeawayEnd = recipe.takeawayDuration(for: anchorBPM)
        let pauseEnd = takeawayEnd + recipe.pauseDuration(for: anchorBPM)
        let impactStart = recipe.swingDuration(for: anchorBPM)
        let impactEnd = impactStart + recipe.impactDuration
        let followThroughEnd = impactEnd + recipe.followThroughDuration

        if elapsedTime < takeawayEnd {
            return 0.58 * smoothstep(elapsedTime / max(takeawayEnd, 0.01))
        }
        if elapsedTime < pauseEnd {
            let progress = (elapsedTime - takeawayEnd) / max(pauseEnd - takeawayEnd, 0.01)
            return 0.58 + (0.04 * smoothstep(progress))
        }
        if elapsedTime < impactStart {
            let progress = (elapsedTime - pauseEnd) / max(impactStart - pauseEnd, 0.01)
            return 0.62 + (0.28 * pow(min(max(progress, 0), 1), 2.35))
        }
        if elapsedTime < impactEnd {
            let progress = (elapsedTime - impactStart) / max(recipe.impactDuration, 0.01)
            return 0.90 + (0.03 * progress)
        }
        if elapsedTime < followThroughEnd {
            let progress = (elapsedTime - impactEnd) / max(recipe.followThroughDuration, 0.01)
            return 0.93 + (0.07 * (1 - pow(1 - min(max(progress, 0), 1), 3)))
        }
        return 1
    }

    private func smoothstep(_ value: Double) -> Double {
        let value = min(max(value, 0), 1)
        return value * value * (3 - (2 * value))
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
    let motionProgress: Double
}
