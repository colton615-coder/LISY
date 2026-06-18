import AVFoundation
import Combine
import SwiftUI
import UIKit

enum GarageTempoPage: String, CaseIterable, Identifiable {
    case metronome
    case guidedSwing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metronome: "Metronome"
        case .guidedSwing: "Guided Swing"
        }
    }
}

enum GarageTempoSessionState: Equatable {
    case ready
    case countingIn
    case resting
    case playing
}

struct GarageTempoSessionConfiguration {
    let page: GarageTempoPage
    let beatsPerMinute: Double
    let recipe: ElasticSlingshotRecipe
    let guidedSound: GarageGuidedSwingProfile
    let startClick: GarageMetronomeClickProfile
    let impactClick: GarageMetronomeClickProfile
    let hapticsEnabled: Bool
}

struct GarageTempoHapticSchedule {
    static func metronomeBeatInterval(recipe: ElasticSlingshotRecipe, beatsPerMinute: Double) -> TimeInterval {
        recipe.slowTempoLogic(for: beatsPerMinute).anchorInterval
    }

}

@MainActor
protocol GarageTempoAudioControlling: AnyObject {
    var playbackState: ElasticSlingshotPlaybackState { get }
    func prepare() -> Bool
    func start(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        metronomeStartProfile: GarageMetronomeClickProfile,
        metronomeImpactProfile: GarageMetronomeClickProfile,
        guidedClicksEnabled: Bool,
        instrumentMode: GarageTempoInstrumentMode
    )
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
    )
    func update(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        metronomeStartProfile: GarageMetronomeClickProfile,
        metronomeImpactProfile: GarageMetronomeClickProfile,
        guidedClicksEnabled: Bool,
        instrumentMode: GarageTempoInstrumentMode
    )
    func stop()
    func currentPlaybackProgress() -> Double
    func currentGuidedCycleSnapshot() -> GarageGuidedSwingCycleSnapshot?
}

@MainActor
protocol GarageTempoCountdownSpeaking: AnyObject {
    func speak(_ value: Int)
    func stop()
}

@MainActor
protocol GarageTempoHapticScheduling: AnyObject {
    func trigger(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
}

@MainActor
final class GarageTempoCountdownSpeaker: ObservableObject, GarageTempoCountdownSpeaking {
    private let synthesizer = AVSpeechSynthesizer()
    private lazy var preferredVoice: AVSpeechSynthesisVoice? = {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && $0.gender == .female }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
            .first
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }()

    func speak(_ value: Int) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: "\(value)")
        utterance.voice = preferredVoice
        utterance.rate = 0.43
        utterance.pitchMultiplier = 0.96
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.04
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

@MainActor
final class GarageTempoHapticScheduler: GarageTempoHapticScheduling {
    func trigger(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: impactIntensity(for: style))
    }

    private func impactIntensity(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> CGFloat {
        switch style {
        case .light:
            return 0.48
        case .medium:
            return 0.70
        case .heavy, .rigid:
            return 1.0
        case .soft:
            return 0.58
        @unknown default:
            return 0.72
        }
    }
}

@MainActor
final class GarageTempoSessionController: ObservableObject {
    @Published private(set) var state = GarageTempoSessionState.ready
    @Published private(set) var appliedBPM = 60.0
    @Published private(set) var countdownValue: Int?
    @Published private(set) var restProgress = 0.0
    @Published private(set) var hasPendingTempo = false
    @Published private(set) var guidedCycleSchedule: GarageGuidedSwingCycleSchedule?

    private let audio: GarageTempoAudioControlling
    private let speaker: GarageTempoCountdownSpeaking
    private let haptics: GarageTempoHapticScheduling
    private let clock = ContinuousClock()
    private var latestConfiguration: GarageTempoSessionConfiguration?
    private var playbackTask: Task<Void, Never>?
    private var hapticTask: Task<Void, Never>?
    private var interruptionCancellable: AnyCancellable?
    private var activeGuidedCycleToken: UInt64?
    private var nextGuidedCycleToken: UInt64 = 1

    init(
        audio: GarageTempoAudioControlling,
        speaker: GarageTempoCountdownSpeaking,
        haptics: GarageTempoHapticScheduling
    ) {
        self.audio = audio
        self.speaker = speaker
        self.haptics = haptics
        interruptionCancellable = NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                guard
                    let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                    AVAudioSession.InterruptionType(rawValue: value) == .began
                else {
                    return
                }
                Task { @MainActor [weak self] in
                    self?.stop()
                }
            }
    }

    convenience init() {
        self.init(
            audio: ElasticSlingshotAudioEngine(),
            speaker: GarageTempoCountdownSpeaker(),
            haptics: GarageTempoHapticScheduler()
        )
    }

    var isActive: Bool { state != .ready }
    var isRunning: Bool { state == .playing }

    func synchronizeReadyBPM(_ beatsPerMinute: Double) {
        guard isActive == false else { return }
        appliedBPM = beatsPerMinute
    }

    func start(_ configuration: GarageTempoSessionConfiguration) {
        cancelScheduledWork()
        latestConfiguration = configuration
        appliedBPM = configuration.beatsPerMinute
        hasPendingTempo = false

        if configuration.page == .guidedSwing {
            startGuidedSequence()
        } else {
            startMetronome(configuration)
        }
    }

    func restartGuidedSwing(_ configuration: GarageTempoSessionConfiguration) {
        guard configuration.page == .guidedSwing, isActive else { return }
        cancelScheduledWork()
        audio.stop()
        latestConfiguration = configuration
        appliedBPM = configuration.beatsPerMinute
        hasPendingTempo = false
        announce("Restarting swing")
        startGuidedSequence()
    }

    func stop() {
        cancelScheduledWork()
        audio.stop()
        state = .ready
        hasPendingTempo = false
    }

    func configurationChanged(_ configuration: GarageTempoSessionConfiguration) {
        latestConfiguration = configuration
        guard isActive else {
            appliedBPM = configuration.beatsPerMinute
            return
        }

        if configuration.page == .guidedSwing {
            let wasPending = hasPendingTempo
            hasPendingTempo = appliedBPM != configuration.beatsPerMinute
            if hasPendingTempo, wasPending == false {
                announce("New tempo applies next swing")
            }
            return
        }

        guard isRunning else { return }
        appliedBPM = configuration.beatsPerMinute
        hasPendingTempo = false
        audio.update(
            beatsPerMinute: appliedBPM,
            recipe: configuration.recipe,
            soundProfile: configuration.guidedSound.engineProfile,
            metronomeStartProfile: configuration.startClick,
            metronomeImpactProfile: configuration.impactClick,
            guidedClicksEnabled: false,
            instrumentMode: .metronome
        )
    }

    func currentPlaybackProgress() -> Double {
        audio.currentPlaybackProgress()
    }

    func currentGuidedCycleSnapshot() -> GarageGuidedSwingCycleSnapshot? {
        guard
            let activeGuidedCycleToken,
            let snapshot = audio.currentGuidedCycleSnapshot(),
            snapshot.token == activeGuidedCycleToken
        else {
            return nil
        }
        return snapshot
    }

    private func startMetronome(_ configuration: GarageTempoSessionConfiguration) {
        audio.start(
            beatsPerMinute: appliedBPM,
            recipe: configuration.recipe,
            soundProfile: configuration.guidedSound.engineProfile,
            metronomeStartProfile: configuration.startClick,
            metronomeImpactProfile: configuration.impactClick,
            guidedClicksEnabled: false,
            instrumentMode: .metronome
        )
        guard audio.playbackState == .playing else {
            state = .ready
            return
        }
        countdownValue = nil
        state = .playing
        scheduleMetronomeHaptics(configuration)
    }

    private func startGuidedSequence() {
        playbackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard audio.prepare() else {
                state = .ready
                return
            }
            await runGuidedCountIn()
            guard Task.isCancelled == false else { return }

            while Task.isCancelled == false {
                guard let configuration = latestConfiguration else { return }
                appliedBPM = configuration.beatsPerMinute
                hasPendingTempo = false
                countdownValue = nil
                restProgress = 0
                let schedule = GarageGuidedSwingCycleSchedule(
                    recipe: configuration.recipe,
                    beatsPerMinute: appliedBPM
                )
                let cycleToken = makeGuidedCycleToken()
                activeGuidedCycleToken = cycleToken
                guidedCycleSchedule = schedule
                audio.playOneCycle(
                    beatsPerMinute: appliedBPM,
                    recipe: configuration.recipe,
                    soundProfile: configuration.guidedSound.engineProfile,
                    metronomeStartProfile: configuration.startClick,
                    metronomeImpactProfile: configuration.impactClick,
                    guidedClicksEnabled: false,
                    instrumentMode: .build,
                    guidedCycleSchedule: schedule,
                    cycleToken: cycleToken
                )
                guard audio.playbackState == .playing else {
                    stop()
                    return
                }
                state = .playing
                let completed = await monitorGuidedCycle(
                    token: cycleToken,
                    schedule: schedule,
                    hapticsEnabled: configuration.hapticsEnabled
                )
                guard Task.isCancelled == false else { return }
                guard completed, activeGuidedCycleToken == cycleToken else { return }
                activeGuidedCycleToken = nil
                guidedCycleSchedule = nil
                state = .resting
                announce("Rest")
                await runRestCountdown(seconds: configuration.recipe.restInterval)
                guard Task.isCancelled == false else { return }
                guard audio.prepare() else {
                    state = .ready
                    return
                }
                await runGuidedCountIn()
                guard Task.isCancelled == false else { return }
            }
        }
    }

    private func runGuidedCountIn() async {
        state = .countingIn
        restProgress = 0
        for value in [3, 2, 1] {
            guard Task.isCancelled == false else { return }
            countdownValue = value
            speaker.speak(value)
            announce("\(value)")
            await sleep(seconds: 1)
        }
    }

    private func runRestCountdown(seconds: TimeInterval) async {
        let interval = max(seconds, 1)
        let start = clock.now
        restProgress = 0

        while Task.isCancelled == false {
            let elapsed = start.duration(to: clock.now).timeInterval
            restProgress = min(max(elapsed / interval, 0), 1)
            guard restProgress < 1 else { return }
            await sleep(seconds: 0.05)
        }
    }

    private func scheduleMetronomeHaptics(_ configuration: GarageTempoSessionConfiguration) {
        hapticTask?.cancel()
        guard configuration.hapticsEnabled else { return }
        let beatInterval = GarageTempoHapticSchedule.metronomeBeatInterval(
            recipe: configuration.recipe,
            beatsPerMinute: appliedBPM
        )
        hapticTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while Task.isCancelled == false, state == .playing {
                haptics.trigger(.light)
                let progress = audio.currentPlaybackProgress()
                let cycleDuration = beatInterval * 4
                let elapsed = progress * cycleDuration
                let nextBeat = (floor(elapsed / beatInterval) + 1) * beatInterval
                await sleep(seconds: max(nextBeat - elapsed, 0.02))
            }
        }
    }

    private func monitorGuidedCycle(
        token: UInt64,
        schedule: GarageGuidedSwingCycleSchedule,
        hapticsEnabled: Bool
    ) async -> Bool {
        var firedTop = false
        var firedImpact = false

        while Task.isCancelled == false, activeGuidedCycleToken == token {
            guard let snapshot = audio.currentGuidedCycleSnapshot(), snapshot.token == token else {
                await sleep(seconds: 0.005)
                continue
            }

            if hapticsEnabled, firedTop == false, snapshot.elapsedTime >= schedule.topOffset {
                firedTop = true
                haptics.trigger(.medium)
            }
            if hapticsEnabled, firedImpact == false, snapshot.elapsedTime >= schedule.impactOffset {
                firedImpact = true
                haptics.trigger(.rigid)
            }
            if snapshot.isComplete {
                return true
            }
            await sleep(seconds: 0.005)
        }
        return false
    }

    private func makeGuidedCycleToken() -> UInt64 {
        let token = nextGuidedCycleToken
        nextGuidedCycleToken &+= 1
        return token
    }

    private func cancelScheduledWork() {
        playbackTask?.cancel()
        playbackTask = nil
        hapticTask?.cancel()
        hapticTask = nil
        activeGuidedCycleToken = nil
        guidedCycleSchedule = nil
        speaker.stop()
        countdownValue = nil
        restProgress = 0
    }

    private func sleep(seconds: TimeInterval) async {
        try? await clock.sleep(for: .seconds(max(seconds, 0)))
    }

    private func announce(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
