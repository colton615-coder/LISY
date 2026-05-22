import AVFoundation
import Combine
import Foundation

struct ElasticSlingshotRecipe: Equatable {
    var tempoRatio: ElasticSlingshotTempoRatio = .tour
    var restInterval: TimeInterval = 5

    var normalizedTakeaway: Double {
        tempoRatio.phaseFractions.takeaway
    }

    var normalizedPause: Double {
        tempoRatio.phaseFractions.pause
    }

    var normalizedDownswing: Double {
        tempoRatio.phaseFractions.downswing
    }

    var displayText: String {
        tempoRatio.title
    }

    func swingDuration(for beatsPerMinute: Double) -> TimeInterval {
        (60 / max(beatsPerMinute, 1)) * 4
    }

    func takeawayDuration(for beatsPerMinute: Double) -> TimeInterval {
        swingDuration(for: beatsPerMinute) * normalizedTakeaway
    }

    func pauseDuration(for beatsPerMinute: Double) -> TimeInterval {
        swingDuration(for: beatsPerMinute) * normalizedPause
    }

    func downswingDuration(for beatsPerMinute: Double) -> TimeInterval {
        swingDuration(for: beatsPerMinute) * normalizedDownswing
    }

    func loopDuration(for beatsPerMinute: Double) -> TimeInterval {
        swingDuration(for: beatsPerMinute) + restInterval
    }
}

enum ElasticSlingshotTempoRatio: String, CaseIterable, Identifiable {
    case punchy
    case tour
    case smooth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .punchy:
            return "2.5:1"
        case .tour:
            return "3:1"
        case .smooth:
            return "4:1"
        }
    }

    private var numericRatio: Double {
        switch self {
        case .punchy:
            return 2.5
        case .tour:
            return 3.0
        case .smooth:
            return 4.0
        }
    }

    var phaseFractions: (takeaway: Double, pause: Double, downswing: Double) {
        let pause = 0.08
        let movingShare = 1 - pause
        let downswing = movingShare / (numericRatio + 1)
        let takeaway = downswing * numericRatio
        return (takeaway: takeaway, pause: pause, downswing: downswing)
    }
}

enum ElasticSlingshotPlaybackState: Equatable {
    case stopped
    case playing
}

enum ElasticSlingshotSoundProfile: String, CaseIterable, Identifiable {
    case power
    case precision
    case flow
    case modern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .power:
            return "Power"
        case .precision:
            return "Precision"
        case .flow:
            return "Flow"
        case .modern:
            return "Modern"
        }
    }

    var description: String {
        switch self {
        case .power:
            return "Heavy snap release"
        case .precision:
            return "Clean measured cues"
        case .flow:
            return "Smooth tempo wave"
        case .modern:
            return "Bright synthetic pulse"
        }
    }
}

private enum ElasticSlingshotPlaybackMode {
    case continuous
    case oneCycle
}

private enum ElasticSlingshotPhase {
    case takeback(progress: Double)
    case pause
    case downswing(progress: Double)
    case loopDelay
    case finished
}

private struct ElasticSlingshotRenderConfiguration {
    var beatsPerMinute: Double
    var recipe: ElasticSlingshotRecipe
    var soundProfile: ElasticSlingshotSoundProfile
    var baseFrame: AVAudioFramePosition
    var mode: ElasticSlingshotPlaybackMode
    var isPlaying: Bool
    var resetToken: Int

    var totalDuration: TimeInterval {
        recipe.swingDuration(for: beatsPerMinute)
    }

    var takebackDuration: TimeInterval {
        totalDuration * recipe.normalizedTakeaway
    }

    var pauseDuration: TimeInterval {
        totalDuration * recipe.normalizedPause
    }

    var downswingDuration: TimeInterval {
        totalDuration * recipe.normalizedDownswing
    }

    var loopDuration: TimeInterval {
        switch mode {
        case .continuous:
            return totalDuration + recipe.restInterval
        case .oneCycle:
            return totalDuration
        }
    }
}

private struct ElasticSlingshotVoiceState {
    var oscillatorPhase = 0.0
    var secondaryPhase = 0.0
    var lastRelativeFrame: AVAudioFramePosition = -1
    var noiseSeed: UInt64 = 0x9E37_79B9_7F4A_7C15

    mutating func resetIfNeeded(relativeFrame: AVAudioFramePosition) {
        guard relativeFrame < lastRelativeFrame else {
            lastRelativeFrame = relativeFrame
            return
        }

        oscillatorPhase = 0
        secondaryPhase = 0
        lastRelativeFrame = relativeFrame
    }

    mutating func advanceOscillator(frequency: Double, sampleRate: Double) -> Double {
        oscillatorPhase = wrapPhase(oscillatorPhase + 2 * Double.pi * frequency / sampleRate)
        return oscillatorPhase
    }

    mutating func advanceSecondary(frequency: Double, sampleRate: Double) -> Double {
        secondaryPhase = wrapPhase(secondaryPhase + 2 * Double.pi * frequency / sampleRate)
        return secondaryPhase
    }

    mutating func nextNoiseSample() -> Double {
        noiseSeed = 2862933555777941757 &* noiseSeed &+ 3037000493
        let normalized = Double((noiseSeed >> 33) & 0xFFFF) / Double(UInt16.max)
        return (normalized * 2) - 1
    }

    private func wrapPhase(_ phase: Double) -> Double {
        if phase > 2 * Double.pi {
            return phase.truncatingRemainder(dividingBy: 2 * Double.pi)
        }

        return phase
    }
}

private final class ElasticSlingshotRenderState {
    private let lock = NSLock()
    private let sampleRate: Double
    private var configuration = ElasticSlingshotRenderConfiguration(
        beatsPerMinute: 75,
        recipe: ElasticSlingshotRecipe(),
        soundProfile: .power,
        baseFrame: 0,
        mode: .continuous,
        isPlaying: false,
        resetToken: 0
    )
    private var latestFrame: AVAudioFramePosition = 0
    private var voiceState = ElasticSlingshotVoiceState()
    private var appliedResetToken = 0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func update(beatsPerMinute: Double, recipe: ElasticSlingshotRecipe, soundProfile: ElasticSlingshotSoundProfile) {
        lock.lock()
        configuration.beatsPerMinute = beatsPerMinute
        configuration.recipe = recipe
        configuration.soundProfile = soundProfile
        lock.unlock()
    }

    func start(beatsPerMinute: Double, recipe: ElasticSlingshotRecipe, soundProfile: ElasticSlingshotSoundProfile, mode: ElasticSlingshotPlaybackMode) {
        lock.lock()
        configuration = ElasticSlingshotRenderConfiguration(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            baseFrame: max(latestFrame, 0) + frames(for: 0.035),
            mode: mode,
            isPlaying: true,
            resetToken: configuration.resetToken + 1
        )
        lock.unlock()
    }

    func stop() {
        lock.lock()
        configuration.isPlaying = false
        lock.unlock()
    }

    func render(
        timestamp: UnsafePointer<AudioTimeStamp>,
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>
    ) -> OSStatus {
        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let startFrame = AVAudioFramePosition(timestamp.pointee.mSampleTime)
        let outputCount = Int(frameCount)

        lock.lock()
        latestFrame = startFrame + AVAudioFramePosition(frameCount)
        let snapshot = configuration
        lock.unlock()

        for buffer in abl {
            guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }

            guard snapshot.isPlaying else {
                clear(data: data, frameCount: outputCount)
                continue
            }

            for frameOffset in 0..<outputCount {
                let absoluteFrame = startFrame + AVAudioFramePosition(frameOffset)
                let sample = sampleValue(at: absoluteFrame, configuration: snapshot)
                data[frameOffset] = Float(max(min(sample, 0.86), -0.86))
            }
        }

        return noErr
    }

    private func sampleValue(at frame: AVAudioFramePosition, configuration: ElasticSlingshotRenderConfiguration) -> Double {
        let relativeFrame = max(frame - configuration.baseFrame, 0)
        if appliedResetToken != configuration.resetToken {
            voiceState = ElasticSlingshotVoiceState()
            appliedResetToken = configuration.resetToken
        }

        voiceState.resetIfNeeded(relativeFrame: relativeFrame)

        switch phase(for: relativeFrame, configuration: configuration) {
        case let .takeback(progress):
            return takebackSample(progress: progress, profile: configuration.soundProfile)
        case .pause, .loopDelay, .finished:
            return 0
        case let .downswing(progress):
            return downswingSample(progress: progress, profile: configuration.soundProfile)
        }
    }

    private func phase(for relativeFrame: AVAudioFramePosition, configuration: ElasticSlingshotRenderConfiguration) -> ElasticSlingshotPhase {
        let elapsed = Double(relativeFrame) / sampleRate
        let totalDuration = max(configuration.totalDuration, 0.05)
        let loopDuration = max(configuration.loopDuration, totalDuration)

        if configuration.mode == .oneCycle, elapsed >= totalDuration {
            return .finished
        }

        let loopElapsed: TimeInterval
        switch configuration.mode {
        case .continuous:
            loopElapsed = elapsed.truncatingRemainder(dividingBy: loopDuration)
        case .oneCycle:
            loopElapsed = elapsed
        }

        let takebackDuration = max(configuration.takebackDuration, 0.001)
        let pauseDuration = max(configuration.pauseDuration, 0)
        let downswingDuration = max(configuration.downswingDuration, 0.001)
        let takebackEnd = takebackDuration
        let pauseEnd = takebackEnd + pauseDuration
        let downswingEnd = pauseEnd + downswingDuration

        if loopElapsed < takebackEnd {
            return .takeback(progress: loopElapsed / takebackDuration)
        }

        if loopElapsed < pauseEnd {
            return .pause
        }

        if loopElapsed < downswingEnd {
            return .downswing(progress: (loopElapsed - pauseEnd) / downswingDuration)
        }

        return .loopDelay
    }

    private func takebackSample(progress: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let progress = min(max(progress, 0), 1)

        switch profile {
        case .power, .flow:
            return analogBandTakeback(progress: progress, drive: drive(for: profile))
        case .precision, .modern:
            return pureSynthTakeback(progress: progress, brightness: brightness(for: profile))
        }
    }

    private func downswingSample(progress: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let progress = min(max(progress, 0), 1)

        switch profile {
        case .power, .flow:
            return analogBandDownswing(progress: progress, drive: drive(for: profile))
        case .precision, .modern:
            return pureSynthDownswing(progress: progress, brightness: brightness(for: profile))
        }
    }

    private func analogBandTakeback(progress: Double, drive: Double) -> Double {
        let frequency = 54 + (132 * pow(progress, 1.25))
        let primaryPhase = voiceState.advanceOscillator(frequency: frequency, sampleRate: sampleRate)
        let secondaryPhase = voiceState.advanceSecondary(frequency: frequency * 0.505, sampleRate: sampleRate)
        let saw = (primaryPhase / Double.pi) - 1
        let sub = sin(secondaryPhase) * 0.42
        let grit = voiceState.nextNoiseSample() * 0.035 * progress * drive
        let envelope = attackReleaseEnvelope(progress: progress, attack: 0.06, release: 0.1)
        let gain = 0.22 + (0.11 * progress)

        return tanh((saw + sub + grit) * drive) * gain * envelope
    }

    private func analogBandDownswing(progress: Double, drive: Double) -> Double {
        let frequency = 185 - (122 * pow(progress, 0.45))
        let phase = voiceState.advanceOscillator(frequency: max(frequency, 42), sampleRate: sampleRate)
        let noise = voiceState.nextNoiseSample()
        let snapEnvelope = exp(-11 * progress)
        let thudEnvelope = exp(-5.2 * progress)
        let click = noise * snapEnvelope * 0.48 * drive
        let thud = sin(phase) * thudEnvelope * 0.56

        return tanh(click + thud)
    }

    private func pureSynthTakeback(progress: Double, brightness: Double) -> Double {
        let frequency = 176 + (420 * smoothstep(progress) * brightness)
        let phase = voiceState.advanceOscillator(frequency: frequency, sampleRate: sampleRate)
        let shimmerPhase = voiceState.advanceSecondary(frequency: frequency * 2.01, sampleRate: sampleRate)
        let envelope = attackReleaseEnvelope(progress: progress, attack: 0.04, release: 0.08)
        let tone = sin(phase) * 0.72 + sin(shimmerPhase) * 0.18

        return tone * envelope * (0.18 + 0.12 * progress)
    }

    private func pureSynthDownswing(progress: Double, brightness: Double) -> Double {
        let frequency = 720 - (520 * smoothstep(progress))
        let phase = voiceState.advanceOscillator(frequency: max(frequency * brightness, 90), sampleRate: sampleRate)
        let chirp = sin(phase) * exp(-9.5 * progress) * 0.42
        let noiseSnap = voiceState.nextNoiseSample() * exp(-13 * progress) * 0.18
        let impact = sin(voiceState.advanceSecondary(frequency: 72, sampleRate: sampleRate)) * exp(-6.5 * progress) * 0.34

        return chirp + noiseSnap + impact
    }

    private func attackReleaseEnvelope(progress: Double, attack: Double, release: Double) -> Double {
        let attackGain = min(progress / max(attack, 0.001), 1)
        let releaseGain = min((1 - progress) / max(release, 0.001), 1)
        return max(min(attackGain, releaseGain), 0)
    }

    private func smoothstep(_ value: Double) -> Double {
        let value = min(max(value, 0), 1)
        return value * value * (3 - 2 * value)
    }

    private func drive(for profile: ElasticSlingshotSoundProfile) -> Double {
        switch profile {
        case .power:
            return 1.48
        case .flow:
            return 0.82
        case .precision, .modern:
            return 1.0
        }
    }

    private func brightness(for profile: ElasticSlingshotSoundProfile) -> Double {
        switch profile {
        case .precision:
            return 0.78
        case .modern:
            return 1.28
        case .power, .flow:
            return 1.0
        }
    }

    private func clear(data: UnsafeMutablePointer<Float>, frameCount: Int) {
        for frameOffset in 0..<frameCount {
            data[frameOffset] = 0
        }
    }

    private func frames(for interval: TimeInterval) -> AVAudioFramePosition {
        AVAudioFramePosition((interval * sampleRate).rounded())
    }
}

@MainActor
final class ElasticSlingshotAudioEngine: ObservableObject {
    @Published private(set) var playbackState: ElasticSlingshotPlaybackState = .stopped

    private let audioEngine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let renderState: ElasticSlingshotRenderState
    private let sourceNode: AVAudioSourceNode
    private var isPrepared = false
    private var previewStopTask: Task<Void, Never>?

    init() {
        let renderState = ElasticSlingshotRenderState(sampleRate: sampleRate)
        self.renderState = renderState
        self.sourceNode = AVAudioSourceNode { _, timestamp, frameCount, audioBufferList in
            renderState.render(timestamp: timestamp, frameCount: frameCount, audioBufferList: audioBufferList)
        }
    }

    func start(beatsPerMinute: Double, recipe: ElasticSlingshotRecipe, soundProfile: ElasticSlingshotSoundProfile) {
        previewStopTask?.cancel()
        previewStopTask = nil
        prepareIfNeeded()
        renderState.start(beatsPerMinute: beatsPerMinute, recipe: recipe, soundProfile: soundProfile, mode: .continuous)
        playbackState = .playing
    }

    func playOneCycle(beatsPerMinute: Double, recipe: ElasticSlingshotRecipe, soundProfile: ElasticSlingshotSoundProfile) {
        previewStopTask?.cancel()
        prepareIfNeeded()
        renderState.start(beatsPerMinute: beatsPerMinute, recipe: recipe, soundProfile: soundProfile, mode: .oneCycle)
        playbackState = .playing

        let previewDuration = recipe.swingDuration(for: beatsPerMinute) + 0.08
        previewStopTask = Task { [weak self] in
            let nanoseconds = UInt64(max(previewDuration, 0.1) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard Task.isCancelled == false else { return }
            await self?.stop()
        }
    }

    func stop() {
        previewStopTask?.cancel()
        previewStopTask = nil
        renderState.stop()
        audioEngine.pause()
        playbackState = .stopped
    }

    func update(beatsPerMinute: Double, recipe: ElasticSlingshotRecipe, soundProfile: ElasticSlingshotSoundProfile) {
        renderState.update(beatsPerMinute: beatsPerMinute, recipe: recipe, soundProfile: soundProfile)
    }

    private func prepareIfNeeded() {
        guard isPrepared == false else {
            if audioEngine.isRunning == false {
                try? audioEngine.start()
            }
            return
        }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }

        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)
        try? audioEngine.start()
        isPrepared = true
    }
}
