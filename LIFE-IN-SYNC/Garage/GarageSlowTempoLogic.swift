import Foundation

struct GarageGuidedSwingCycleSchedule: Equatable {
    static let topArcProgress = 0.58
    static let downswingArcProgress = 0.62

    let addressOffset: TimeInterval
    let topOffset: TimeInterval
    let downswingOffset: TimeInterval
    let impactOffset: TimeInterval
    let completionOffset: TimeInterval
    let impactDuration: TimeInterval

    init(recipe: ElasticSlingshotRecipe, beatsPerMinute: Double) {
        addressOffset = 0
        topOffset = recipe.takeawayDuration(for: beatsPerMinute)
        downswingOffset = topOffset + recipe.pauseDuration(for: beatsPerMinute)
        impactOffset = recipe.swingDuration(for: beatsPerMinute)
        completionOffset = recipe.guidedMotionDuration(for: beatsPerMinute)
        impactDuration = recipe.impactDuration
    }

    func elapsedTime(for progress: Double) -> TimeInterval {
        min(max(progress, 0), 1) * completionOffset
    }

    func cycleProgress(at elapsedTime: TimeInterval) -> Double {
        min(max(elapsedTime / max(completionOffset, 0.01), 0), 1)
    }

    func motionProgress(at elapsedTime: TimeInterval) -> Double {
        if elapsedTime < topOffset {
            return Self.topArcProgress * smoothstep(elapsedTime / max(topOffset, 0.01))
        }
        if elapsedTime < downswingOffset {
            let progress = (elapsedTime - topOffset) / max(downswingOffset - topOffset, 0.01)
            return Self.topArcProgress
                + ((Self.downswingArcProgress - Self.topArcProgress) * smoothstep(progress))
        }
        if elapsedTime < impactOffset {
            let progress = (elapsedTime - downswingOffset) / max(impactOffset - downswingOffset, 0.01)
            return Self.downswingArcProgress
                + ((1 - Self.downswingArcProgress) * pow(min(max(progress, 0), 1), 2.35))
        }
        return 1
    }

    func reducedMotionProgress(at elapsedTime: TimeInterval) -> Double {
        if elapsedTime < topOffset { return 0 }
        if elapsedTime < downswingOffset { return Self.topArcProgress }
        if elapsedTime < impactOffset { return Self.downswingArcProgress }
        return 1
    }

    func impactPulseProgress(at elapsedTime: TimeInterval) -> Double {
        let pulseDuration = min(max(completionOffset - impactOffset, impactDuration), 0.34)
        guard elapsedTime >= impactOffset, pulseDuration > 0 else { return 0 }
        return min(max((elapsedTime - impactOffset) / pulseDuration, 0), 1)
    }

    private func smoothstep(_ value: Double) -> Double {
        let value = min(max(value, 0), 1)
        return value * value * (3 - (2 * value))
    }
}

struct GarageGuidedSwingCycleSnapshot: Equatable {
    let token: UInt64
    let elapsedTime: TimeInterval
    let progress: Double
    let isComplete: Bool
}

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
        takeawayDuration(for: .tour)
    }

    var impactTimestamp: TimeInterval {
        swingDuration
    }

    func takeawayDuration(for tempoRatio: ElasticSlingshotTempoRatio) -> TimeInterval {
        swingDuration * tempoRatio.backswingMotionFraction
    }

    func topHoldDuration(for tempoRatio: ElasticSlingshotTempoRatio) -> TimeInterval {
        swingDuration * tempoRatio.topSetMotionFraction
    }

    func downswingDuration(for tempoRatio: ElasticSlingshotTempoRatio) -> TimeInterval {
        max(swingDuration - takeawayDuration(for: tempoRatio) - topHoldDuration(for: tempoRatio), 0.05)
    }

    var tempoTitle: String {
        "\(Int(anchorBPM.rounded())) BPM anchor"
    }

    var trainingMapText: String {
        "Address → Top → Impact"
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
                title: "Address",
                cue: "Start smooth.",
                isTransition: false
            ),
            GarageSlowTempoLandmark(
                beat: 2,
                title: "Top",
                cue: "Set the top.",
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

    func visualState(
        elapsedTime: TimeInterval,
        isPlaying: Bool,
        recipe: ElasticSlingshotRecipe,
        schedule: GarageGuidedSwingCycleSchedule
    ) -> GarageSlowTempoVisualState {
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

        let swingDuration = max(schedule.impactOffset, 0.1)
        let cycleDuration = max(recipe.loopDuration(for: anchorBPM), swingDuration)
        let elapsedInCycle = elapsedTime.truncatingRemainder(dividingBy: cycleDuration)
        let impactEndTimestamp = schedule.impactOffset + schedule.impactDuration
        let activeBeat: Int
        let nextIndex: Int
        let phaseLabel: String
        let phaseCue: String
        let isResting: Bool

        if elapsedInCycle < schedule.topOffset {
            activeBeat = 1
            nextIndex = 1
            phaseLabel = elapsedInCycle <= 0.08 ? landmarks[0].title : "Backswing"
            phaseCue = landmarks[0].cue
            isResting = false
        } else if elapsedInCycle < schedule.downswingOffset {
            activeBeat = 2
            nextIndex = 2
            phaseLabel = landmarks[1].title
            phaseCue = recipe.tempoRatio.feelLine
            isResting = false
        } else if elapsedInCycle < schedule.impactOffset {
            activeBeat = 2
            nextIndex = 2
            phaseLabel = "Downswing"
            phaseCue = "Release clean."
            isResting = false
        } else if elapsedInCycle < schedule.completionOffset {
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
            cycleProgress: schedule.cycleProgress(at: elapsedInCycle),
            activeBeat: activeBeat,
            activeLandmark: activeLandmark,
            nextLandmark: landmarks[nextIndex],
            phaseLabel: phaseLabel,
            phaseCue: phaseCue,
            isResting: isResting,
            motionProgress: schedule.motionProgress(at: elapsedInCycle)
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
    let motionProgress: Double
}
