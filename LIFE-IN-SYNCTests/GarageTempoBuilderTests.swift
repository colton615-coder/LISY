import Testing
import UIKit
@testable import LIFE_IN_SYNC

struct GarageTempoBuilderTests {
    @Test func guidedMotionProgressIsMonotonicThroughFollowThrough() {
        let recipe = ElasticSlingshotRecipe()
        let logic = recipe.slowTempoLogic(for: 60)
        let duration = recipe.guidedMotionDuration(for: 60)
        let samples = stride(from: 0.0, through: duration, by: 0.02).map {
            logic.visualState(elapsedTime: $0, isPlaying: true, recipe: recipe).motionProgress
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

    @Test func guidedSoundGroupsContainEveryProfileExactlyOnce() {
        let grouped = GarageGuidedSwingProfile.cleanAndPrecise + GarageGuidedSwingProfile.weightAndAir

        #expect(Set(grouped).count == GarageGuidedSwingProfile.allCases.count)
        #expect(grouped.count == GarageGuidedSwingProfile.allCases.count)
    }

    @Test func hapticScheduleContainsOneTopAndOneImpactEvent() {
        let recipe = ElasticSlingshotRecipe()
        let offsets = GarageTempoHapticSchedule.guidedLandmarkOffsets(recipe: recipe, beatsPerMinute: 60)

        #expect(offsets.count == 2)
        #expect(offsets[0] == recipe.takeawayDuration(for: 60))
        #expect(offsets[1] == recipe.swingDuration(for: 60))
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
            guidedSound: .tension,
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
        instrumentMode: GarageTempoInstrumentMode
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
