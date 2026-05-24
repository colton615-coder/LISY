import AVFoundation
import Combine
import Foundation

private let elasticSlingshotStopFadeDuration: TimeInterval = 0.09
private let elasticSlingshotImpactDuration: TimeInterval = 0.08
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
        (60 / max(beatsPerMinute, 1)) * tempoRatio.totalBeatCount
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

    var backswingBeatCount: Double {
        switch self {
        case .punchy:
            return 2.5
        case .tour:
            return 3.0
        case .smooth:
            return 4.0
        }
    }

    var pauseBeatCount: Double {
        0.15
    }

    var downswingBeatCount: Double {
        1
    }

    var totalBeatCount: Double {
        backswingBeatCount + pauseBeatCount + downswingBeatCount
    }

    var phaseFractions: (takeaway: Double, pause: Double, downswing: Double) {
        (
            takeaway: backswingBeatCount / totalBeatCount,
            pause: pauseBeatCount / totalBeatCount,
            downswing: downswingBeatCount / totalBeatCount
        )
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
    case impactPreview

    var debugName: String {
        switch self {
        case .continuous:
            return "continuous"
        case .oneCycle:
            return "oneCycle"
        case .impactPreview:
            return "impactPreview"
        }
    }
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
    var impactTone: ToneProfile
    var impactModifier: ShapeModifier
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
        case .oneCycle, .impactPreview:
            return totalDuration
        }
    }
}

private struct ElasticSlingshotVoiceState {
    var oscillatorPhase = 0.0
    var secondaryPhase = 0.0
    var lastRelativeFrame: AVAudioFramePosition = -1
    var lastImpactDebugLogKey = ""
    var noiseSeed: UInt64 = 0x9E37_79B9_7F4A_7C15

    mutating func resetIfNeeded(relativeFrame: AVAudioFramePosition) {
        guard relativeFrame < lastRelativeFrame else {
            lastRelativeFrame = relativeFrame
            return
        }

        oscillatorPhase = 0
        secondaryPhase = 0
        lastImpactDebugLogKey = ""
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

private struct ElasticSlingshotImpactToneParameters {
    let frequency: Double
    let secondaryMultiplier: Double
    let noiseAmount: Double
    let drive: Double
    let gain: Double
    let decayRate: Double
    let bend: Double
    let tremoloDepth: Double
    let primaryMix: Double
    let secondaryMix: Double
    let bodyMix: Double
    let waveform: ElasticSlingshotImpactWaveform

    init(
        frequency: Double,
        secondaryMultiplier: Double,
        noiseAmount: Double,
        drive: Double,
        gain: Double,
        decayRate: Double = 10.2,
        bend: Double = 0,
        tremoloDepth: Double = 0,
        primaryMix: Double = 0.62,
        secondaryMix: Double = 0.24,
        bodyMix: Double = 0.16,
        waveform: ElasticSlingshotImpactWaveform
    ) {
        self.frequency = frequency
        self.secondaryMultiplier = secondaryMultiplier
        self.noiseAmount = noiseAmount
        self.drive = drive
        self.gain = gain
        self.decayRate = decayRate
        self.bend = bend
        self.tremoloDepth = tremoloDepth
        self.primaryMix = primaryMix
        self.secondaryMix = secondaryMix
        self.bodyMix = bodyMix
        self.waveform = waveform
    }
}

private enum ElasticSlingshotImpactWaveform {
    case sine
    case square
    case click
    case noise
}

private final class ElasticSlingshotRenderState {
    private let lock = NSLock()
    private let sampleRate: Double
    private var configuration = ElasticSlingshotRenderConfiguration(
        beatsPerMinute: 75,
        recipe: ElasticSlingshotRecipe(),
        soundProfile: .power,
        impactTone: ToneLibrary.defaultImpactTone,
        impactModifier: .raw,
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

    func update(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        impactTone: ToneProfile,
        impactModifier: ShapeModifier
    ) {
        lock.lock()
        configuration.beatsPerMinute = beatsPerMinute
        configuration.recipe = recipe
        configuration.soundProfile = soundProfile
        configuration.impactTone = impactTone
        configuration.impactModifier = impactModifier
        lock.unlock()
    }

    func start(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        impactTone: ToneProfile,
        impactModifier: ShapeModifier,
        mode: ElasticSlingshotPlaybackMode
    ) {
        lock.lock()
        configuration = ElasticSlingshotRenderConfiguration(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            impactTone: impactTone,
            impactModifier: impactModifier,
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
            debugLogImpactIfNeeded(at: relativeFrame, configuration: configuration)
            rawSample = impactSample(
                progress: progress,
                tone: configuration.impactTone,
                modifier: configuration.impactModifier
            )
        case .loopDelay, .finished:
            rawSample = 0
        }

        return rawSample * playbackEnvelope(at: frame, configuration: configuration)
    }

    private func phase(for relativeFrame: AVAudioFramePosition, configuration: ElasticSlingshotRenderConfiguration) -> ElasticSlingshotPhase {
        let totalFrames = max(frames(for: configuration.totalDuration), 1)
        let loopFrames = max(frames(for: configuration.loopDuration), totalFrames)
        let impactDurationFrames = max(frames(for: elasticSlingshotImpactDuration), 1)

        if configuration.mode == .impactPreview {
            guard relativeFrame < impactDurationFrames else {
                return .finished
            }

            return .impact(progress: Double(relativeFrame) / Double(impactDurationFrames))
        }

        if configuration.mode == .oneCycle, relativeFrame >= totalFrames + impactDurationFrames {
            return .finished
        }

        let cycleFrame: AVAudioFramePosition
        switch configuration.mode {
        case .continuous:
            cycleFrame = relativeFrame % loopFrames
        case .oneCycle, .impactPreview:
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

    private func debugLogImpactIfNeeded(
        at relativeFrame: AVAudioFramePosition,
        configuration: ElasticSlingshotRenderConfiguration
    ) {
        let impactDurationFrames = max(frames(for: elasticSlingshotImpactDuration), 1)
        let loopFrames = max(frames(for: configuration.loopDuration), impactDurationFrames)
        let cycleIndex: AVAudioFramePosition

        switch configuration.mode {
        case .continuous:
            cycleIndex = relativeFrame / loopFrames
        case .oneCycle, .impactPreview:
            cycleIndex = 0
        }

        let key = [
            "\(configuration.resetToken)",
            "\(cycleIndex)",
            configuration.impactTone.id,
            configuration.impactModifier.rawValue
        ].joined(separator: ":")

        guard voiceState.lastImpactDebugLogKey != key else { return }
        voiceState.lastImpactDebugLogKey = key
        print("[ToneVault] impact synthesis tone=\(configuration.impactTone.id) asset=\(configuration.impactTone.assetName) modifier=\(configuration.impactModifier.rawValue) mode=\(configuration.mode.debugName)")
    }

    private func takebackSample(progress: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let progress = min(max(progress, 0), 1)

        switch profile {
        case .power:
            return analogBandTone(
                frequency: pitchFrequency(for: .takeback(progress: progress)),
                envelope: attackEnvelope(progress: progress, attack: 0.035),
                drive: drive(for: profile),
                noiseAmount: 0.032 * progress
            )
        case .precision:
            return pureSynthTone(
                frequency: pitchFrequency(for: .takeback(progress: progress)),
                envelope: attackEnvelope(progress: progress, attack: 0.018),
                brightness: brightness(for: profile),
                shimmer: 0.035
            )
        case .flow:
            return flowWaveTone(
                frequency: pitchFrequency(for: .takeback(progress: progress)) * 0.72,
                envelope: attackEnvelope(progress: progress, attack: 0.08) * 0.82
            )
        case .modern:
            return modernPulseTone(
                frequency: pitchFrequency(for: .takeback(progress: progress)) * 1.18,
                envelope: attackEnvelope(progress: progress, attack: 0.012)
            )
        }
    }

    private func pauseSample(releaseGain: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let releaseGain = min(max(releaseGain, 0), 1)
        let frequency = pitchFrequency(for: .pause(releaseGain: releaseGain))
        switch profile {
        case .power:
            return analogBandTone(
                frequency: frequency,
                envelope: 0.92 * releaseGain,
                drive: drive(for: profile),
                noiseAmount: 0
            )
        case .precision:
            return pureSynthTone(
                frequency: frequency,
                envelope: 0.88 * releaseGain,
                brightness: brightness(for: profile),
                shimmer: 0.035
            )
        case .flow:
            return flowWaveTone(
                frequency: frequency * 0.72,
                envelope: 0.68 * releaseGain
            )
        case .modern:
            return modernPulseTone(
                frequency: frequency * 1.18,
                envelope: 0.82 * releaseGain
            )
        }
    }

    private func impactSample(progress: Double, tone: ToneProfile, modifier: ShapeModifier) -> Double {
        let progress = min(max(progress, 0), 1)
        let parameters = impactParameters(for: tone)
        let bentFrequency = max(parameters.frequency * pow(2, parameters.bend * (1 - progress)), 40)
        let snapPhase = voiceState.advanceOscillator(frequency: bentFrequency, sampleRate: sampleRate)
        let tickPhase = voiceState.advanceSecondary(
            frequency: bentFrequency * parameters.secondaryMultiplier,
            sampleRate: sampleRate
        )
        let noise = voiceState.nextNoiseSample()

        let primary: Double
        switch parameters.waveform {
        case .sine:
            primary = sin(snapPhase) * parameters.primaryMix
        case .square:
            primary = (sin(snapPhase) >= 0 ? parameters.primaryMix : -parameters.primaryMix)
        case .click:
            primary = sin(snapPhase) * parameters.primaryMix + sin(tickPhase) * parameters.secondaryMix
        case .noise:
            primary = noise * parameters.primaryMix + sin(snapPhase) * parameters.secondaryMix
        }

        let body = sin(tickPhase) * parameters.bodyMix
        let burst = noise * parameters.noiseAmount
        let tremolo = 1 - parameters.tremoloDepth + (parameters.tremoloDepth * abs(sin(tickPhase * 0.5)))
        return tanh((primary + body + burst) * parameters.drive) * parameters.gain * tremolo * impactEnvelope(
            progress: progress,
            modifier: modifier,
            toneDecayRate: parameters.decayRate
        )
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

    private func flowWaveTone(frequency: Double, envelope: Double) -> Double {
        let adjustedFrequency = max(frequency, 70)
        let phase = voiceState.advanceOscillator(frequency: adjustedFrequency, sampleRate: sampleRate)
        let secondaryPhase = voiceState.advanceSecondary(frequency: adjustedFrequency * 1.5, sampleRate: sampleRate)
        let rounded = sin(phase) * 0.62
        let air = sin(secondaryPhase) * 0.10

        return tanh(rounded + air) * envelope * 0.22
    }

    private func modernPulseTone(frequency: Double, envelope: Double) -> Double {
        let adjustedFrequency = max(frequency, 120)
        let phase = voiceState.advanceOscillator(frequency: adjustedFrequency, sampleRate: sampleRate)
        let secondaryPhase = voiceState.advanceSecondary(frequency: adjustedFrequency * 2.62, sampleRate: sampleRate)
        let pulse = sin(phase) >= 0 ? 0.68 : -0.68
        let edge = sin(secondaryPhase) * 0.18

        return tanh(pulse + edge) * envelope * 0.20
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

    private func impactParameters(for tone: ToneProfile) -> ElasticSlingshotImpactToneParameters {
        switch tone.id {
        case "woodblock":
            return ElasticSlingshotImpactToneParameters(frequency: 1_060, secondaryMultiplier: 2.75, noiseAmount: 0.12, drive: 1.70, gain: 1.00, decayRate: 18.0, primaryMix: 0.86, secondaryMix: 0.44, bodyMix: 0.06, waveform: .click)
        case "snare_rim":
            return ElasticSlingshotImpactToneParameters(frequency: 2_150, secondaryMultiplier: 3.40, noiseAmount: 0.95, drive: 1.90, gain: 0.96, decayRate: 24.0, primaryMix: 0.48, secondaryMix: 0.24, bodyMix: 0.04, waveform: .noise)
        case "cowbell":
            return ElasticSlingshotImpactToneParameters(frequency: 620, secondaryMultiplier: 1.43, noiseAmount: 0.02, drive: 1.38, gain: 1.00, decayRate: 7.0, primaryMix: 0.84, secondaryMix: 0.52, bodyMix: 0.28, waveform: .sine)
        case "shaker":
            return ElasticSlingshotImpactToneParameters(frequency: 3_600, secondaryMultiplier: 5.20, noiseAmount: 1.40, drive: 0.90, gain: 0.88, decayRate: 11.5, tremoloDepth: 0.54, primaryMix: 1.00, secondaryMix: 0.04, bodyMix: 0.02, waveform: .noise)
        case "ping":
            return ElasticSlingshotImpactToneParameters(frequency: 2_720, secondaryMultiplier: 2.00, noiseAmount: 0.00, drive: 0.92, gain: 0.92, decayRate: 4.6, primaryMix: 0.88, secondaryMix: 0.34, bodyMix: 0.22, waveform: .sine)
        case "hihat":
            return ElasticSlingshotImpactToneParameters(frequency: 5_800, secondaryMultiplier: 1.90, noiseAmount: 1.65, drive: 1.18, gain: 0.82, decayRate: 32.0, primaryMix: 1.08, secondaryMix: 0.02, bodyMix: 0.01, waveform: .noise)
        case "clave":
            return ElasticSlingshotImpactToneParameters(frequency: 1_480, secondaryMultiplier: 2.18, noiseAmount: 0.08, drive: 1.62, gain: 0.98, decayRate: 16.0, primaryMix: 0.76, secondaryMix: 0.58, bodyMix: 0.08, waveform: .click)
        case "sine_808":
            return ElasticSlingshotImpactToneParameters(frequency: 74, secondaryMultiplier: 2.00, noiseAmount: 0.01, drive: 2.35, gain: 1.00, decayRate: 3.6, bend: -0.22, primaryMix: 1.15, secondaryMix: 0.00, bodyMix: 0.34, waveform: .sine)
        case "square_lead":
            return ElasticSlingshotImpactToneParameters(frequency: 1_320, secondaryMultiplier: 2.00, noiseAmount: 0.02, drive: 1.28, gain: 0.88, decayRate: 8.5, primaryMix: 0.92, secondaryMix: 0.00, bodyMix: 0.12, waveform: .square)
        case "fm_tine":
            return ElasticSlingshotImpactToneParameters(frequency: 1_940, secondaryMultiplier: 3.77, noiseAmount: 0.00, drive: 1.05, gain: 0.90, decayRate: 5.6, primaryMix: 0.68, secondaryMix: 0.60, bodyMix: 0.42, waveform: .sine)
        case "saw_stab":
            return ElasticSlingshotImpactToneParameters(frequency: 510, secondaryMultiplier: 1.25, noiseAmount: 0.26, drive: 2.05, gain: 0.96, decayRate: 6.8, bend: 0.12, primaryMix: 1.00, secondaryMix: 0.18, bodyMix: 0.20, waveform: .square)
        case "laser":
            return ElasticSlingshotImpactToneParameters(frequency: 1_120, secondaryMultiplier: 1.06, noiseAmount: 0.02, drive: 1.12, gain: 0.88, decayRate: 6.2, bend: 1.35, primaryMix: 0.95, secondaryMix: 0.08, bodyMix: 0.12, waveform: .sine)
        case "pulse":
            return ElasticSlingshotImpactToneParameters(frequency: 420, secondaryMultiplier: 4.00, noiseAmount: 0.08, drive: 1.52, gain: 0.92, decayRate: 10.0, tremoloDepth: 0.72, primaryMix: 0.88, secondaryMix: 0.00, bodyMix: 0.28, waveform: .square)
        case "kazoo":
            return ElasticSlingshotImpactToneParameters(frequency: 370, secondaryMultiplier: 1.72, noiseAmount: 0.46, drive: 2.20, gain: 0.90, decayRate: 5.2, bend: -0.12, primaryMix: 0.94, secondaryMix: 0.40, bodyMix: 0.36, waveform: .square)
        case "balloon_pop":
            return ElasticSlingshotImpactToneParameters(frequency: 140, secondaryMultiplier: 2.40, noiseAmount: 1.55, drive: 1.80, gain: 1.00, decayRate: 22.0, bend: -0.75, primaryMix: 1.18, secondaryMix: 0.12, bodyMix: 0.00, waveform: .noise)
        case "rubber_duck":
            return ElasticSlingshotImpactToneParameters(frequency: 780, secondaryMultiplier: 1.09, noiseAmount: 0.10, drive: 2.10, gain: 0.92, decayRate: 4.4, bend: 0.58, primaryMix: 0.98, secondaryMix: 0.20, bodyMix: 0.18, waveform: .square)
        case "golf_click":
            return ElasticSlingshotImpactToneParameters(frequency: 1_620, secondaryMultiplier: 2.32, noiseAmount: 0.62, drive: 1.58, gain: 0.98, decayRate: 20.0, primaryMix: 0.74, secondaryMix: 0.32, bodyMix: 0.05, waveform: .click)
        case "spring":
            return ElasticSlingshotImpactToneParameters(frequency: 360, secondaryMultiplier: 3.60, noiseAmount: 0.02, drive: 1.22, gain: 0.90, decayRate: 3.8, bend: 0.82, tremoloDepth: 0.62, primaryMix: 0.86, secondaryMix: 0.48, bodyMix: 0.44, waveform: .sine)
        case "whistle":
            return ElasticSlingshotImpactToneParameters(frequency: 3_400, secondaryMultiplier: 1.01, noiseAmount: 0.00, drive: 0.82, gain: 0.80, decayRate: 4.2, primaryMix: 1.00, secondaryMix: 0.00, bodyMix: 0.02, waveform: .sine)
        case "cork_pop":
            return ElasticSlingshotImpactToneParameters(frequency: 240, secondaryMultiplier: 1.66, noiseAmount: 1.18, drive: 1.96, gain: 0.98, decayRate: 14.0, bend: -0.36, primaryMix: 1.05, secondaryMix: 0.24, bodyMix: 0.18, waveform: .noise)
        case "bell_ring":
            return ElasticSlingshotImpactToneParameters(frequency: 1_980, secondaryMultiplier: 2.98, noiseAmount: 0.00, drive: 1.02, gain: 0.92, decayRate: 3.2, primaryMix: 0.72, secondaryMix: 0.70, bodyMix: 0.50, waveform: .sine)
        default:
            return ElasticSlingshotImpactToneParameters(frequency: 1_620, secondaryMultiplier: 2.32, noiseAmount: 0.62, drive: 1.58, gain: 0.98, decayRate: 20.0, primaryMix: 0.74, secondaryMix: 0.32, bodyMix: 0.05, waveform: .click)
        }
    }

    private func impactEnvelope(progress: Double, modifier: ShapeModifier, toneDecayRate: Double) -> Double {
        let progress = min(max(progress, 0), 1)
        switch modifier {
        case .raw:
            return exp(-toneDecayRate * progress)
        case .snappy:
            return exp(-(toneDecayRate * 2.05) * progress)
        case .lingering:
            return exp(-(toneDecayRate * 0.42) * progress)
        case .reversed:
            return pow(progress, 0.42) * exp(-(toneDecayRate * 0.24) * max(progress - 0.72, 0))
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

    func start(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        impactTone: ToneProfile,
        impactModifier: ShapeModifier
    ) {
        previewStopTask?.cancel()
        previewStopTask = nil
        fadeStopTask?.cancel()
        fadeStopTask = nil
        prepareIfNeeded()
        renderState.start(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            impactTone: impactTone,
            impactModifier: impactModifier,
            mode: .continuous
        )
        playbackState = .playing
    }

    func playOneCycle(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        impactTone: ToneProfile,
        impactModifier: ShapeModifier
    ) {
        previewStopTask?.cancel()
        previewStopTask = nil
        fadeStopTask?.cancel()
        fadeStopTask = nil
        prepareIfNeeded()
        renderState.silence()
        print("[ToneVault] preview tap tone=\(impactTone.id) asset=\(impactTone.assetName) modifier=\(impactModifier.rawValue)")
        renderState.start(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            impactTone: impactTone,
            impactModifier: impactModifier,
            mode: .impactPreview
        )
        playbackState = .playing

        let previewDuration = elasticSlingshotImpactDuration + 0.04
        previewStopTask = Task { [weak self] in
            let nanoseconds = UInt64(max(previewDuration, 0.1) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard Task.isCancelled == false else { return }
            await self?.finishImpactPreview()
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

    private func finishImpactPreview() {
        renderState.silence()
        audioEngine.pause()
        previewStopTask = nil
        playbackState = .stopped
    }

    func update(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        impactTone: ToneProfile,
        impactModifier: ShapeModifier
    ) {
        renderState.update(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            impactTone: impactTone,
            impactModifier: impactModifier
        )
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
