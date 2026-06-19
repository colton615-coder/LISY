import Testing
import UIKit
@testable import LIFE_IN_SYNC

struct GarageTempoBuilderTests {
    @Test func guidedMotionProgressIsMonotonicThroughFollowThrough() {
        let recipe = ElasticSlingshotRecipe()
        let logic = recipe.slowTempoLogic(for: 60)
        let schedule = GarageGuidedSwingCycleSchedule(recipe: recipe, beatsPerMinute: 60)
        let duration = recipe.guidedMotionDuration(for: 60)
        let samples = stride(from: 0.0, through: duration, by: 0.02).map {
            logic.visualState(
                elapsedTime: $0,
                isPlaying: true,
                recipe: recipe,
                schedule: schedule
            ).motionProgress
        }

        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(samples.first == 0)
        #expect(samples.last == 1)
    }

    @Test func metronomeSoundGroupsContainEveryProfileExactlyOnce() {
        let grouped = GarageMetronomeClickProfile.crispMarkers
            + GarageMetronomeClickProfile.softPractice
            + GarageMetronomeClickProfile.signalAccents
            + GarageMetronomeClickProfile.digitalSynthetic

        #expect(Set(grouped).count == GarageMetronomeClickProfile.allCases.count)
        #expect(grouped.count == GarageMetronomeClickProfile.allCases.count)
    }

    @Test func guidedListeningOrderContainsEveryRemodeledProfileExactlyOnce() {
        let grouped = GarageGuidedSwingProfile.listeningOrder.map(\.audioProfileID)

        #expect(Set(grouped).count == GarageGuidedSwingAudioProfileID.allCases.count)
        #expect(grouped.count == GarageGuidedSwingAudioProfileID.allCases.count)
    }

    @Test func guidedSoundIdentitiesUseGeneratedNativeLayers() {
        let phases: [TempoSoundPhase] = [.build, .top, .downswing, .impact, .tail]
        for profile in TempoSoundIdentityProfile.allCases {
            #expect(phases.allSatisfy { profile.eventPlan[$0].assetName == nil })
            #expect(phases.allSatisfy { profile.eventPlan[$0].synthesisGain > 0 })
        }
    }

    @Test func guidedIdentityImpactsOwnTheStrongestPhaseGain() {
        for profile in TempoSoundIdentityProfile.allCases {
            let plan = profile.eventPlan
            let supportingGains = [
                plan[.build].synthesisGain,
                plan[.top].synthesisGain,
                plan[.downswing].synthesisGain,
                plan[.tail].synthesisGain
            ]

            #expect(plan[.impact].synthesisGain > supportingGains.max()!)
        }
    }

    @Test func hapticScheduleContainsOneTopAndOneImpactEvent() {
        let recipe = ElasticSlingshotRecipe()
        let schedule = GarageGuidedSwingCycleSchedule(recipe: recipe, beatsPerMinute: 60)

        #expect(schedule.topOffset == recipe.takeawayDuration(for: 60))
        #expect(schedule.downswingOffset == schedule.topOffset + recipe.pauseDuration(for: 60))
        #expect(schedule.impactOffset == recipe.swingDuration(for: 60))
        #expect(schedule.completionOffset == recipe.guidedMotionDuration(for: 60))
        #expect(GarageTempoHapticSchedule.metronomeBeatInterval(recipe: recipe, beatsPerMinute: 60) == 1)
    }

    @MainActor
    @Test func restartBeginsFreshCountInAndStopClearsSessionState() async {
        let audio = GarageTempoAudioMock()
        let speaker = GarageTempoSpeakerMock()
        let haptics = GarageTempoHapticMock()
        let controller = GarageTempoSessionController(audio: audio, speaker: speaker, haptics: haptics)
        let configuration = makeConfiguration(page: .guidedSwing, beatsPerMinute: 60)

        controller.start(configuration)
        await Task.yield()
        #expect(controller.state == .countingIn)
        #expect(controller.countdownValue == 3)

        controller.restartGuidedSwing(configuration)
        await Task.yield()
        #expect(controller.state == .countingIn)
        #expect(controller.countdownValue == 3)

        controller.stop()
        #expect(controller.state == .ready)
        #expect(controller.countdownValue == nil)
        #expect(controller.restProgress == 0)
        #expect(audio.stopCount == 2)
    }

    @MainActor
    @Test func guidedTempoWaitsForNextSwingWhileMetronomeUpdatesLive() {
        let audio = GarageTempoAudioMock()
        let controller = GarageTempoSessionController(
            audio: audio,
            speaker: GarageTempoSpeakerMock(),
            haptics: GarageTempoHapticMock()
        )

        controller.start(makeConfiguration(page: .guidedSwing, beatsPerMinute: 60))
        controller.configurationChanged(makeConfiguration(page: .guidedSwing, beatsPerMinute: 65))
        #expect(controller.appliedBPM == 60)
        #expect(controller.hasPendingTempo)
        controller.stop()

        controller.start(makeConfiguration(page: .metronome, beatsPerMinute: 60))
        controller.configurationChanged(makeConfiguration(page: .metronome, beatsPerMinute: 65))
        #expect(controller.appliedBPM == 65)
        #expect(audio.updateCount == 1)
        controller.stop()
    }

    private func makeConfiguration(page: GarageTempoPage, beatsPerMinute: Double) -> GarageTempoSessionConfiguration {
        GarageTempoSessionConfiguration(
            page: page,
            beatsPerMinute: beatsPerMinute,
            recipe: ElasticSlingshotRecipe(),
            guidedSound: .tourWhip,
            startClick: .woodblock,
            impactClick: .brightSignal,
            hapticsEnabled: false
        )
    }
}

@MainActor
private final class GarageTempoAudioMock: GarageTempoAudioControlling {
    var playbackState = ElasticSlingshotPlaybackState.stopped
    var stopCount = 0
    var updateCount = 0

    func prepare() -> Bool {
        true
    }

    func start(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        metronomeStartProfile: GarageMetronomeClickProfile,
        metronomeImpactProfile: GarageMetronomeClickProfile,
        guidedClicksEnabled: Bool,
        instrumentMode: GarageTempoInstrumentMode
    ) {
        playbackState = .playing
    }

    func playOneCycle(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        metronomeStartProfile: GarageMetronomeClickProfile,
        metronomeImpactProfile: GarageMetronomeClickProfile,
        guidedClicksEnabled: Bool,
        instrumentMode: GarageTempoInstrumentMode,
        guidedCycleSchedule: GarageGuidedSwingCycleSchedule?,
        cycleToken: UInt64
    ) {
        playbackState = .playing
    }

    func update(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        metronomeStartProfile: GarageMetronomeClickProfile,
        metronomeImpactProfile: GarageMetronomeClickProfile,
        guidedClicksEnabled: Bool,
        instrumentMode: GarageTempoInstrumentMode
    ) {
        updateCount += 1
    }

    func stop() {
        stopCount += 1
        playbackState = .stopped
    }

    func currentPlaybackProgress() -> Double {
        0
    }

    func currentGuidedCycleSnapshot() -> GarageGuidedSwingCycleSnapshot? {
        nil
    }
}

@MainActor
private final class GarageTempoSpeakerMock: GarageTempoCountdownSpeaking {
    func speak(_ value: Int) {}
    func stop() {}
}

@MainActor
private final class GarageTempoHapticMock: GarageTempoHapticScheduling {
    func trigger(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {}
}
