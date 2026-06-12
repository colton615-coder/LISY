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

    static func guidedLandmarkOffsets(recipe: ElasticSlingshotRecipe, beatsPerMinute: Double) -> [TimeInterval] {
        let top = recipe.takeawayDuration(for: beatsPerMinute)
        let impact = top + recipe.pauseDuration(for: beatsPerMinute) + recipe.downswingDuration(for: beatsPerMinute)
        return [top, impact]
    }
}

@MainActor
protocol GarageTempoAudioControlling: AnyObject {
    var playbackState: ElasticSlingshotPlaybackState { get }
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
        instrumentMode: GarageTempoInstrumentMode
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
        utterance.volume = 0.86
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
        generator.impactOccurred()
    }
}

@MainActor
final class GarageTempoSessionController: ObservableObject {
    @Published private(set) var state = GarageTempoSessionState.ready
    @Published private(set) var appliedBPM = 60.0
    @Published private(set) var countdownValue: Int?
    @Published private(set) var restProgress = 0.0
    @Published private(set) var hasPendingTempo = false

    private let audio: GarageTempoAudioControlling
    private let speaker: GarageTempoCountdownSpeaking
    private let haptics: GarageTempoHapticScheduling
    private let clock = ContinuousClock()
    private var latestConfiguration: GarageTempoSessionConfiguration?
    private var playbackTask: Task<Void, Never>?
    private var hapticTask: Task<Void, Never>?
    private var interruptionCancellable: AnyCancellable?

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
            await runGuidedCountIn()
            guard Task.isCancelled == false else { return }

            while Task.isCancelled == false {
                guard let configuration = latestConfiguration else { return }
                appliedBPM = configuration.beatsPerMinute
                hasPendingTempo = false
                countdownValue = nil
                restProgress = 0
                state = .playing
                audio.playOneCycle(
                    beatsPerMinute: appliedBPM,
                    recipe: configuration.recipe,
                    soundProfile: configuration.guidedSound.engineProfile,
                    metronomeStartProfile: configuration.startClick,
                    metronomeImpactProfile: configuration.impactClick,
                    guidedClicksEnabled: false,
                    instrumentMode: .build
                )
                guard audio.playbackState == .playing else {
                    stop()
                    return
                }
                scheduleGuidedHaptics(configuration)
                await sleep(seconds: configuration.recipe.guidedMotionDuration(for: appliedBPM))
                guard Task.isCancelled == false else { return }
                state = .resting
                announce("Rest")
                await runRestCountdown(seconds: configuration.recipe.restInterval)
                guard Task.isCancelled == false else { return }
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
            if latestConfiguration?.hapticsEnabled == true {
                haptics.trigger(.light)
            }
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

    private func scheduleGuidedHaptics(_ configuration: GarageTempoSessionConfiguration) {
        hapticTask?.cancel()
        guard configuration.hapticsEnabled else { return }
        let offsets = GarageTempoHapticSchedule.guidedLandmarkOffsets(
            recipe: configuration.recipe,
            beatsPerMinute: appliedBPM
        )
        hapticTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await sleep(seconds: offsets[0])
            guard Task.isCancelled == false else { return }
            haptics.trigger(.light)
            await sleep(seconds: offsets[1] - offsets[0])
            guard Task.isCancelled == false else { return }
            haptics.trigger(.rigid)
        }
    }

    private func cancelScheduledWork() {
        playbackTask?.cancel()
        playbackTask = nil
        hapticTask?.cancel()
        hapticTask = nil
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
