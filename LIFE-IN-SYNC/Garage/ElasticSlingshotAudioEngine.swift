import AVFoundation
import Combine
import Foundation

private let elasticSlingshotStopFadeDuration: TimeInterval = 0.09
private let elasticSlingshotImpactDuration: TimeInterval = 0.04
private let elasticSlingshotToneReleaseFrames: AVAudioFramePosition = 2

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
    case pause(releaseGain: Double)
    case downswing
    case impact(progress: Double)
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
    var fadeOutStartFrame: AVAudioFramePosition?
    var alignsBaseFrameOnNextRender: Bool
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
        fadeOutStartFrame: nil,
        alignsBaseFrameOnNextRender: false,
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
            baseFrame: max(latestFrame, 0),
            mode: mode,
            isPlaying: true,
            fadeOutStartFrame: nil,
            alignsBaseFrameOnNextRender: true,
            resetToken: configuration.resetToken + 1
        )
        lock.unlock()
    }

    func stop() {
        lock.lock()
        if configuration.isPlaying, configuration.fadeOutStartFrame == nil {
            configuration.fadeOutStartFrame = max(latestFrame, 0)
        }
        lock.unlock()
    }

    func silence() {
        lock.lock()
        configuration.isPlaying = false
        configuration.fadeOutStartFrame = nil
        configuration.alignsBaseFrameOnNextRender = false
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
        if configuration.alignsBaseFrameOnNextRender {
            configuration.baseFrame = startFrame
            configuration.alignsBaseFrameOnNextRender = false
        }
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

        let rawSample: Double
        switch phase(for: relativeFrame, configuration: configuration) {
        case let .takeback(progress):
            rawSample = takebackSample(progress: progress, profile: configuration.soundProfile)
        case let .pause(releaseGain):
            rawSample = pauseSample(releaseGain: releaseGain, profile: configuration.soundProfile)
        case .downswing:
            rawSample = 0
        case let .impact(progress):
            rawSample = impactSample(progress: progress, profile: configuration.soundProfile)
        case .loopDelay, .finished:
            rawSample = 0
        }

        return rawSample * playbackEnvelope(at: frame, configuration: configuration)
    }

    private func phase(for relativeFrame: AVAudioFramePosition, configuration: ElasticSlingshotRenderConfiguration) -> ElasticSlingshotPhase {
        let totalFrames = max(frames(for: configuration.totalDuration), 1)
        let loopFrames = max(frames(for: configuration.loopDuration), totalFrames)
        let impactDurationFrames = max(frames(for: elasticSlingshotImpactDuration), 1)

        if configuration.mode == .oneCycle, relativeFrame >= totalFrames + impactDurationFrames {
            return .finished
        }

        let cycleFrame: AVAudioFramePosition
        switch configuration.mode {
        case .continuous:
            cycleFrame = relativeFrame % loopFrames
        case .oneCycle:
            cycleFrame = relativeFrame
        }

        let takebackFrames = max(frames(for: configuration.takebackDuration), 1)
        let pauseFrames = max(frames(for: configuration.pauseDuration), 0)
        let pauseEndFrame = takebackFrames + pauseFrames

        if cycleFrame < takebackFrames {
            return .takeback(progress: Double(cycleFrame) / Double(takebackFrames))
        }

        if cycleFrame < pauseEndFrame {
            let framesUntilDownswing = pauseEndFrame - cycleFrame
            let releaseProgress = min(Double(framesUntilDownswing) / Double(max(elasticSlingshotToneReleaseFrames, 1)), 1)
            return .pause(releaseGain: releaseProgress)
        }

        if cycleFrame < totalFrames {
            return .downswing
        }

        if cycleFrame < totalFrames + impactDurationFrames {
            let impactFrame = cycleFrame - totalFrames
            return .impact(progress: Double(impactFrame) / Double(impactDurationFrames))
        }

        return .loopDelay
    }

    private func takebackSample(progress: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let progress = min(max(progress, 0), 1)

        switch profile {
        case .power, .flow:
            return analogBandTone(
                frequency: pitchFrequency(for: .takeback(progress: progress)),
                envelope: attackEnvelope(progress: progress, attack: 0.035),
                drive: drive(for: profile),
                noiseAmount: 0.018 * progress
            )
        case .precision, .modern:
            return pureSynthTone(
                frequency: pitchFrequency(for: .takeback(progress: progress)),
                envelope: attackEnvelope(progress: progress, attack: 0.025),
                brightness: brightness(for: profile),
                shimmer: 0.16
            )
        }
    }

    private func pauseSample(releaseGain: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let releaseGain = min(max(releaseGain, 0), 1)
        let frequency = pitchFrequency(for: .pause(releaseGain: releaseGain))
        switch profile {
        case .power, .flow:
            return analogBandTone(
                frequency: frequency,
                envelope: 0.92 * releaseGain,
                drive: drive(for: profile),
                noiseAmount: 0
            )
        case .precision, .modern:
            return pureSynthTone(
                frequency: frequency,
                envelope: 0.88 * releaseGain,
                brightness: brightness(for: profile),
                shimmer: 0.16
            )
        }
    }

    private func impactSample(progress: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let progress = min(max(progress, 0), 1)
        let snapFrequency = impactFrequency(for: profile)
        let snapPhase = voiceState.advanceOscillator(frequency: snapFrequency, sampleRate: sampleRate)
        let tickPhase = voiceState.advanceSecondary(frequency: snapFrequency * 1.74, sampleRate: sampleRate)
        let noise = voiceState.nextNoiseSample()
        let envelope = exp(-11.5 * progress)
        let needle = sin(snapPhase) * 0.52
        let glass = sin(tickPhase) * 0.22
        let burst = noise * 0.62

        return tanh((needle + glass + burst) * drive(for: profile)) * envelope
    }

    private func analogBandTone(frequency: Double, envelope: Double, drive: Double, noiseAmount: Double) -> Double {
        let primaryPhase = voiceState.advanceOscillator(frequency: frequency, sampleRate: sampleRate)
        let secondaryPhase = voiceState.advanceSecondary(frequency: frequency * 0.502, sampleRate: sampleRate)
        let saw = (primaryPhase / Double.pi) - 1
        let sub = sin(secondaryPhase) * 0.34
        let grit = voiceState.nextNoiseSample() * noiseAmount * drive

        return tanh((saw + sub + grit) * drive) * 0.24 * envelope
    }

    private func pureSynthTone(frequency: Double, envelope: Double, brightness: Double, shimmer: Double) -> Double {
        let adjustedFrequency = max(frequency * brightness, 90)
        let phase = voiceState.advanceOscillator(frequency: adjustedFrequency, sampleRate: sampleRate)
        let shimmerPhase = voiceState.advanceSecondary(frequency: adjustedFrequency * 2.01, sampleRate: sampleRate)
        let tone = sin(phase) * 0.72 + sin(shimmerPhase) * shimmer

        return tone * envelope * 0.24
    }

    private func pitchFrequency(for phase: ElasticSlingshotPhase) -> Double {
        switch phase {
        case let .takeback(progress):
            return exponentialRamp(from: 220, to: 880, progress: pow(min(max(progress, 0), 1), 1.08))
        case .pause:
            return 880
        case .downswing, .impact, .loopDelay, .finished:
            return 0
        }
    }

    private func exponentialRamp(from start: Double, to end: Double, progress: Double) -> Double {
        let progress = min(max(progress, 0), 1)
        return start * pow(end / start, progress)
    }

    private func attackEnvelope(progress: Double, attack: Double) -> Double {
        min(progress / max(attack, 0.001), 1)
    }

    private func playbackEnvelope(at frame: AVAudioFramePosition, configuration: ElasticSlingshotRenderConfiguration) -> Double {
        guard let fadeOutStartFrame = configuration.fadeOutStartFrame else {
            return 1
        }

        let elapsedFrames = max(frame - fadeOutStartFrame, 0)
        let fadeOutFrames = max(frames(for: elasticSlingshotStopFadeDuration), 1)
        let progress = min(Double(elapsedFrames) / Double(fadeOutFrames), 1)
        return 1 - smoothstep(progress)
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

    private func impactFrequency(for profile: ElasticSlingshotSoundProfile) -> Double {
        switch profile {
        case .power:
            return 1_280
        case .precision:
            return 1_520
        case .flow:
            return 1_180
        case .modern:
            return 1_760
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
    private var fadeStopTask: Task<Void, Never>?

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
        fadeStopTask?.cancel()
        fadeStopTask = nil
        prepareIfNeeded()
        renderState.start(beatsPerMinute: beatsPerMinute, recipe: recipe, soundProfile: soundProfile, mode: .continuous)
        playbackState = .playing
    }

    func playOneCycle(beatsPerMinute: Double, recipe: ElasticSlingshotRecipe, soundProfile: ElasticSlingshotSoundProfile) {
        previewStopTask?.cancel()
        fadeStopTask?.cancel()
        fadeStopTask = nil
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
        fadeStopTask?.cancel()
        renderState.stop()
        playbackState = .stopped

        fadeStopTask = Task { [weak self] in
            let nanoseconds = UInt64(elasticSlingshotStopFadeDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard Task.isCancelled == false else { return }
            await self?.finishStopAfterFade()
        }
    }

    private func finishStopAfterFade() {
        renderState.silence()
        audioEngine.pause()
        fadeStopTask = nil
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
        // Swing Capture records with the microphone; keep this category compatible with capture so the tempo engine keeps playing.
        try? session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
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
