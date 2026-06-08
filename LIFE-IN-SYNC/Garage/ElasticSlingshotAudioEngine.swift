import AVFoundation
import Combine
import Foundation

private let elasticSlingshotStopFadeDuration: TimeInterval = 0.09
private let elasticSlingshotImpactDuration: TimeInterval = 0.08
private let elasticSlingshotToneReleaseFrames: AVAudioFramePosition = 2
private let elasticSlingshotAnchorPulseDuration: TimeInterval = 0.07
private let elasticSlingshotSubdivisionTickDuration: TimeInterval = 0.035

struct ElasticSlingshotRecipe: Equatable {
    var tempoRatio: ElasticSlingshotTempoRatio = .tour
    var restInterval: TimeInterval = 5
    var subdivisionMultiplier = GarageSlowTempoLogic.defaultSubdivisionMultiplier

    var normalizedTakeaway: Double {
        let duration = max(swingDuration(for: GarageSlowTempoLogic.defaultAnchorBPM), 0.01)
        return takeawayDuration(for: GarageSlowTempoLogic.defaultAnchorBPM) / duration
    }

    var normalizedPause: Double {
        let duration = max(swingDuration(for: GarageSlowTempoLogic.defaultAnchorBPM), 0.01)
        return pauseDuration(for: GarageSlowTempoLogic.defaultAnchorBPM) / duration
    }

    var normalizedDownswing: Double {
        let duration = max(swingDuration(for: GarageSlowTempoLogic.defaultAnchorBPM), 0.01)
        return downswingDuration(for: GarageSlowTempoLogic.defaultAnchorBPM) / duration
    }

    var displayText: String {
        tempoRatio.displayTitle
    }

    func swingDuration(for beatsPerMinute: Double) -> TimeInterval {
        slowTempoLogic(for: beatsPerMinute).swingDuration
    }

    func takeawayDuration(for beatsPerMinute: Double) -> TimeInterval {
        slowTempoLogic(for: beatsPerMinute).anchorInterval
    }

    func pauseDuration(for beatsPerMinute: Double) -> TimeInterval {
        slowTempoLogic(for: beatsPerMinute).topHoldDuration(for: tempoRatio)
    }

    func downswingDuration(for beatsPerMinute: Double) -> TimeInterval {
        slowTempoLogic(for: beatsPerMinute).downswingDuration(for: tempoRatio)
    }

    func loopDuration(for beatsPerMinute: Double) -> TimeInterval {
        swingDuration(for: beatsPerMinute) + elasticSlingshotImpactDuration + restInterval
    }

    func slowTempoLogic(for beatsPerMinute: Double) -> GarageSlowTempoLogic {
        GarageSlowTempoLogic(
            anchorBPM: beatsPerMinute,
            subdivisionMultiplier: subdivisionMultiplier
        )
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

    var displayTitle: String {
        switch self {
        case .punchy:
            return "Athletic"
        case .tour:
            return "Balanced"
        case .smooth:
            return "Stretched"
        }
    }

    var feelLine: String {
        switch self {
        case .punchy:
            return "Quicker load. Crisp release."
        case .tour:
            return "Classic load. Clean transition."
        case .smooth:
            return "Longer load. More patience at the top."
        }
    }

    var detailText: String {
        "\(title) swing shape"
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

    var topHoldBeatFraction: Double {
        switch self {
        case .punchy:
            return 0.10
        case .tour:
            return 0.16
        case .smooth:
            return 0.24
        }
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

enum GarageTempoInstrumentMode: String, CaseIterable, Identifiable {
    case metronome
    case build

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metronome:
            return "Metronome"
        case .build:
            return "Build"
        }
    }

    var shortTitle: String {
        switch self {
        case .metronome:
            return "Click"
        case .build:
            return "Pressure"
        }
    }

    var subtitle: String {
        switch self {
        case .metronome:
            return "Strict wood/digital count"
        case .build:
            return "Continuous pressure trainer"
        }
    }
}

enum GarageMetronomeClickProfile: String, CaseIterable, Identifiable {
    case hardwood
    case ball
    case steel
    case leather
    case stone
    case rim
    case pulse
    case glass
    case signal
    case core

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hardwood: "Hardwood"
        case .ball: "Strike"
        case .steel: "Steel"
        case .leather: "Leather"
        case .stone: "Stone"
        case .rim: "Rim"
        case .pulse: "Digital"
        case .glass: "Air"
        case .signal: "Signal"
        case .core: "Core"
        }
    }

    var character: String {
        switch self {
        case .hardwood: "Dry and warm"
        case .ball: "Strong physical strike"
        case .steel: "Bright without bite"
        case .leather: "Tight muted snap"
        case .stone: "Low speaker-friendly body"
        case .rim: "Crisp and dry"
        case .pulse: "Tight digital marker"
        case .glass: "Soft headphone-friendly air"
        case .signal: "Clear speaker marker"
        case .core: "Balanced firm impact"
        }
    }
}

enum GarageGuidedSwingProfile: String, CaseIterable, Identifiable {
    case tension
    case vector
    case mass
    case sharpPulse
    case airStrike
    case deepStrike

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tension: "Clean Pulse"
        case .vector: "Glass Tick"
        case .mass: "Low Punch"
        case .sharpPulse: "Sharp Pulse"
        case .airStrike: "Air Strike"
        case .deepStrike: "Deep Strike"
        }
    }

    var character: String {
        switch self {
        case .tension: "Sharp, precise build with a clean strike."
        case .vector: "Bright, tight build with a precise strike."
        case .mass: "Deeper build with a compact impact."
        case .sharpPulse: "Clean digital build with a firm strike."
        case .airStrike: "Light, clean rise with a crisp impact."
        case .deepStrike: "Low pressure build with a strong impact."
        }
    }

    var engineProfile: ElasticSlingshotSoundProfile {
        switch self {
        case .tension: .elastic
        case .vector: .glass
        case .mass: .gravity
        case .sharpPulse: .pulse
        case .airStrike: .airframe
        case .deepStrike: .storm
        }
    }
}

enum ElasticSlingshotSoundProfile: String, CaseIterable, Identifiable {
    case elastic
    case storm
    case airframe
    case reed
    case pulse
    case gravity
    case glass
    case rubber

    var id: String { rawValue }

    var title: String {
        switch self {
        case .elastic:
            return "Elastic"
        case .storm:
            return "Storm"
        case .airframe:
            return "Airframe"
        case .reed:
            return "Reed"
        case .pulse:
            return "Pulse"
        case .gravity:
            return "Gravity"
        case .glass:
            return "Glass"
        case .rubber:
            return "Rubber"
        }
    }

    var description: String {
        switch self {
        case .elastic:
            return "Smooth stretch, calm release, sharp snap."
        case .storm:
            return "Low pressure build, thunder body, bright strike."
        case .airframe:
            return "Breathy lift, clean trail, crisp snap."
        case .reed:
            return "Controlled reed texture with playful edge."
        case .pulse:
            return "Modern rhythm pressure with surgical impact."
        case .gravity:
            return "Deep load, soft fall, bright strike."
        case .glass:
            return "Clean shimmer, tight top, precise snap."
        case .rubber:
            return "Elastic training feel without toy energy."
        }
    }
}

private enum ElasticSlingshotPlaybackMode {
    case continuous
    case oneCycle

    var debugName: String {
        switch self {
        case .continuous:
            return "continuous"
        case .oneCycle:
            return "oneCycle"
        }
    }
}

private enum ElasticSlingshotPhase {
    case takeback(progress: Double)
    case pause(releaseGain: Double)
    case downswing(progress: Double)
    case impact(progress: Double)
    case loopDelay
    case finished
}

private struct ElasticSlingshotRenderConfiguration {
    var beatsPerMinute: Double
    var recipe: ElasticSlingshotRecipe
    var soundProfile: ElasticSlingshotSoundProfile
    var metronomeClickProfile: GarageMetronomeClickProfile
    var guidedClicksEnabled: Bool
    var instrumentMode: GarageTempoInstrumentMode
    var baseFrame: AVAudioFramePosition
    var mode: ElasticSlingshotPlaybackMode
    var isPlaying: Bool
    var fadeOutStartFrame: AVAudioFramePosition?
    var alignsBaseFrameOnNextRender: Bool
    var resetToken: Int

    var totalDuration: TimeInterval {
        recipe.swingDuration(for: beatsPerMinute)
    }

    var slowTempoLogic: GarageSlowTempoLogic {
        recipe.slowTempoLogic(for: beatsPerMinute)
    }

    var takebackDuration: TimeInterval {
        recipe.takeawayDuration(for: beatsPerMinute)
    }

    var pauseDuration: TimeInterval {
        recipe.pauseDuration(for: beatsPerMinute)
    }

    var downswingDuration: TimeInterval {
        recipe.downswingDuration(for: beatsPerMinute)
    }

    var loadReleaseTimestamp: TimeInterval {
        takebackDuration + pauseDuration
    }

    var loopDuration: TimeInterval {
        if instrumentMode == .metronome {
            return slowTempoLogic.anchorInterval
        }

        switch mode {
        case .continuous:
            return recipe.loopDuration(for: beatsPerMinute)
        case .oneCycle:
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

private enum GarageMetronomeClickWaveform {
    case tonal
    case muted
    case square
    case physical
}

private struct GarageMetronomeClickTuning {
    let bodyCycles: Double
    let edgeCycles: Double
    let bodyMix: Double
    let edgeMix: Double
    let noiseMix: Double
    let decayRate: Double
    let gain: Double
    let drive: Double
    let waveform: GarageMetronomeClickWaveform
}

private final class ElasticSlingshotRenderState {
    private let lock = NSLock()
    private let sampleRate: Double
    private var configuration = ElasticSlingshotRenderConfiguration(
        beatsPerMinute: 75,
        recipe: ElasticSlingshotRecipe(),
        soundProfile: .elastic,
        metronomeClickProfile: .hardwood,
        guidedClicksEnabled: false,
        instrumentMode: .build,
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
        metronomeClickProfile: GarageMetronomeClickProfile,
        guidedClicksEnabled: Bool,
        instrumentMode: GarageTempoInstrumentMode
    ) {
        lock.lock()
        let timingChanged = configuration.beatsPerMinute != beatsPerMinute
            || configuration.recipe != recipe
            || configuration.instrumentMode != instrumentMode
        let voiceChanged = configuration.soundProfile != soundProfile
            || configuration.metronomeClickProfile != metronomeClickProfile
        configuration.beatsPerMinute = beatsPerMinute
        configuration.recipe = recipe
        configuration.soundProfile = soundProfile
        configuration.metronomeClickProfile = metronomeClickProfile
        configuration.guidedClicksEnabled = guidedClicksEnabled
        configuration.instrumentMode = instrumentMode
        if configuration.isPlaying, timingChanged {
            configuration.baseFrame = max(latestFrame, 0)
            configuration.alignsBaseFrameOnNextRender = true
        }
        if configuration.isPlaying, timingChanged || voiceChanged {
            configuration.resetToken += 1
        }
        lock.unlock()
    }

    func start(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        metronomeClickProfile: GarageMetronomeClickProfile,
        guidedClicksEnabled: Bool,
        instrumentMode: GarageTempoInstrumentMode,
        mode: ElasticSlingshotPlaybackMode
    ) {
        lock.lock()
        configuration = ElasticSlingshotRenderConfiguration(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            metronomeClickProfile: metronomeClickProfile,
            guidedClicksEnabled: guidedClicksEnabled,
            instrumentMode: instrumentMode,
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
            rawSample = configuration.instrumentMode == .metronome ? 0 : takebackSample(progress: progress, profile: configuration.soundProfile)
        case let .pause(releaseGain):
            rawSample = configuration.instrumentMode == .metronome ? 0 : pauseSample(releaseGain: releaseGain, profile: configuration.soundProfile)
        case let .downswing(progress):
            rawSample = configuration.instrumentMode == .metronome ? 0 : downswingTrailSample(progress: progress, profile: configuration.soundProfile)
        case let .impact(progress):
            debugLogImpactIfNeeded(at: relativeFrame, configuration: configuration)
            rawSample = configuration.instrumentMode == .metronome ? 0 : impactSample(progress: progress, profile: configuration.soundProfile)
        case .loopDelay:
            rawSample = 0
        case .finished:
            rawSample = 0
        }

        let cueSample = buildCueSample(at: relativeFrame, configuration: configuration)
        let guideSample = slowTempoGuideSample(at: relativeFrame, configuration: configuration)
        return (rawSample + cueSample + guideSample) * playbackEnvelope(at: frame, configuration: configuration)
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
            let downswingFrames = max(totalFrames - pauseEndFrame, 1)
            let downswingFrame = max(cycleFrame - pauseEndFrame, 0)
            return .downswing(progress: Double(downswingFrame) / Double(downswingFrames))
        }

        if cycleFrame < totalFrames + impactDurationFrames {
            let impactFrame = cycleFrame - totalFrames
            return .impact(progress: Double(impactFrame) / Double(impactDurationFrames))
        }

        return .loopDelay
    }

    private func slowTempoGuideSample(
        at relativeFrame: AVAudioFramePosition,
        configuration: ElasticSlingshotRenderConfiguration
    ) -> Double {
        let totalFrames = max(frames(for: configuration.totalDuration), 1)
        let loopFrames = max(frames(for: configuration.loopDuration), totalFrames)

        let cycleFrame: AVAudioFramePosition
        switch configuration.mode {
        case .continuous:
            cycleFrame = relativeFrame % loopFrames
        case .oneCycle:
            cycleFrame = relativeFrame
        }

        if configuration.instrumentMode == .metronome {
            return metronomeGuideSample(
                cycleFrame: cycleFrame,
                eventFrame: 0,
                duration: 0.040,
                gain: 1,
                configuration: configuration
            )
        }

        guard configuration.guidedClicksEnabled, cycleFrame < totalFrames else { return 0 }

        let beatFrames = max(frames(for: configuration.slowTempoLogic.anchorInterval), 1)
        let clickFrame = cycleFrame % beatFrames
        return metronomeGuideSample(
            cycleFrame: clickFrame,
            eventFrame: beatFrames / 2,
            duration: 0.028,
            gain: 0.32,
            configuration: configuration
        )

    }

    private func metronomeGuideSample(
        cycleFrame: AVAudioFramePosition,
        eventFrame: AVAudioFramePosition,
        duration: TimeInterval,
        gain: Double,
        configuration: ElasticSlingshotRenderConfiguration
    ) -> Double {
        let pulseFrames = max(frames(for: duration), 1)
        if let progress = eventProgress(
            cycleFrame: cycleFrame,
            eventFrame: eventFrame,
            durationFrames: pulseFrames
        ) {
            return metronomeClickSample(
                progress: progress,
                profile: configuration.metronomeClickProfile
            ) * gain
        }

        return 0
    }

    private func metronomeClickSample(progress: Double, profile: GarageMetronomeClickProfile) -> Double {
        let progress = min(max(progress, 0), 1)
        let tuning = metronomeClickTuning(for: profile)
        let noise = voiceState.nextNoiseSample()
        let phase = progress * Double.pi
        let body = sin(phase * tuning.bodyCycles)
        let edge = sin(phase * tuning.edgeCycles)
        let shapedBody: Double

        switch tuning.waveform {
        case .tonal:
            shapedBody = body
        case .muted:
            shapedBody = tanh(body * 0.82)
        case .square:
            shapedBody = body >= 0 ? 0.72 : -0.72
        case .physical:
            shapedBody = tanh((body * 0.78) + (noise * 0.16))
        }

        let transient = (shapedBody * tuning.bodyMix) + (edge * tuning.edgeMix) + (noise * tuning.noiseMix)
        let envelope = exp(-tuning.decayRate * progress)
        return tanh(transient * tuning.drive) * tuning.gain * envelope
    }

    private func metronomeClickTuning(for profile: GarageMetronomeClickProfile) -> GarageMetronomeClickTuning {
        switch profile {
        case .hardwood:
            return GarageMetronomeClickTuning(bodyCycles: 17, edgeCycles: 35, bodyMix: 0.76, edgeMix: 0.12, noiseMix: 0.04, decayRate: 31, gain: 0.36, drive: 1.05, waveform: .muted)
        case .ball:
            return GarageMetronomeClickTuning(bodyCycles: 25, edgeCycles: 43, bodyMix: 0.72, edgeMix: 0.12, noiseMix: 0.10, decayRate: 38, gain: 0.39, drive: 1.18, waveform: .physical)
        case .steel:
            return GarageMetronomeClickTuning(bodyCycles: 42, edgeCycles: 67, bodyMix: 0.66, edgeMix: 0.11, noiseMix: 0, decayRate: 39, gain: 0.34, drive: 0.94, waveform: .tonal)
        case .leather:
            return GarageMetronomeClickTuning(bodyCycles: 13, edgeCycles: 27, bodyMix: 0.72, edgeMix: 0.06, noiseMix: 0.12, decayRate: 44, gain: 0.39, drive: 1.08, waveform: .muted)
        case .stone:
            return GarageMetronomeClickTuning(bodyCycles: 9, edgeCycles: 19, bodyMix: 0.82, edgeMix: 0.07, noiseMix: 0.06, decayRate: 34, gain: 0.42, drive: 1.14, waveform: .physical)
        case .rim:
            return GarageMetronomeClickTuning(bodyCycles: 34, edgeCycles: 57, bodyMix: 0.70, edgeMix: 0.13, noiseMix: 0.02, decayRate: 43, gain: 0.36, drive: 1.02, waveform: .tonal)
        case .pulse:
            return GarageMetronomeClickTuning(bodyCycles: 19, edgeCycles: 37, bodyMix: 0.68, edgeMix: 0.08, noiseMix: 0, decayRate: 39, gain: 0.34, drive: 0.92, waveform: .square)
        case .glass:
            return GarageMetronomeClickTuning(bodyCycles: 48, edgeCycles: 72, bodyMix: 0.61, edgeMix: 0.08, noiseMix: 0, decayRate: 43, gain: 0.31, drive: 0.88, waveform: .tonal)
        case .signal:
            return GarageMetronomeClickTuning(bodyCycles: 29, edgeCycles: 49, bodyMix: 0.74, edgeMix: 0.10, noiseMix: 0.01, decayRate: 40, gain: 0.37, drive: 0.98, waveform: .tonal)
        case .core:
            return GarageMetronomeClickTuning(bodyCycles: 15, edgeCycles: 31, bodyMix: 0.78, edgeMix: 0.09, noiseMix: 0.07, decayRate: 36, gain: 0.40, drive: 1.20, waveform: .physical)
        }
    }

    private func buildCueSample(
        at relativeFrame: AVAudioFramePosition,
        configuration: ElasticSlingshotRenderConfiguration
    ) -> Double {
        guard configuration.instrumentMode == .build else { return 0 }

        let loopFrames = max(frames(for: configuration.loopDuration), 1)
        let cycleFrame = configuration.mode == .continuous ? relativeFrame % loopFrames : relativeFrame
        let totalFrames = max(frames(for: configuration.totalDuration), 1)
        guard cycleFrame < totalFrames else { return 0 }

        let startFrames = max(frames(for: elasticSlingshotAnchorPulseDuration), 1)
        if let progress = eventProgress(cycleFrame: cycleFrame, eventFrame: 0, durationFrames: startFrames) {
            return startAnchorPulseSample(progress: progress, profile: configuration.soundProfile)
        }

        let topFrame = max(frames(for: configuration.takebackDuration), 1)
        let topFrames = max(frames(for: 0.055), 1)
        if let progress = eventProgress(cycleFrame: cycleFrame, eventFrame: topFrame, durationFrames: topFrames) {
            return topAnchorPulseSample(progress: progress, profile: configuration.soundProfile)
        }

        return 0
    }

    private func buildResetPulseBed(
        at relativeFrame: AVAudioFramePosition,
        configuration: ElasticSlingshotRenderConfiguration
    ) -> Double {
        let loopFrames = max(frames(for: configuration.loopDuration), 1)
        let cycleFrame = relativeFrame % loopFrames
        let swingFrames = max(frames(for: configuration.totalDuration), 1)
        guard cycleFrame >= swingFrames else { return 0 }

        let restFrame = cycleFrame - swingFrames
        let restFrames = max(loopFrames - swingFrames, 1)
        let pulseIntervalFrames = max(frames(for: max(configuration.slowTempoLogic.anchorInterval * 0.5, 0.25)), 1)
        let pulseFrame = restFrame % pulseIntervalFrames
        let pulseProgress = Double(pulseFrame) / Double(pulseIntervalFrames)
        let restProgress = Double(restFrame) / Double(restFrames)
        let envelope = exp(-10 * pulseProgress) * (0.55 + (0.45 * restProgress))
        let phase = voiceState.advanceSecondary(frequency: 112, sampleRate: sampleRate)

        return sin(phase) * envelope * 0.045
    }

    private func eventProgress(
        cycleFrame: AVAudioFramePosition,
        eventFrame: AVAudioFramePosition,
        durationFrames: AVAudioFramePosition
    ) -> Double? {
        guard cycleFrame >= eventFrame, cycleFrame < eventFrame + durationFrames else { return nil }
        return Double(cycleFrame - eventFrame) / Double(max(durationFrames, 1))
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
        case .oneCycle:
            cycleIndex = 0
        }

        let key = [
            "\(configuration.resetToken)",
            "\(cycleIndex)",
            configuration.soundProfile.rawValue
        ].joined(separator: ":")

        guard voiceState.lastImpactDebugLogKey != key else { return }
        voiceState.lastImpactDebugLogKey = key
        print("[TempoAudio] guided impact profile=\(configuration.soundProfile.rawValue) mode=\(configuration.mode.debugName)")
    }

    private func takebackSample(progress: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let progress = min(max(progress, 0), 1)
        let frequency = pitchFrequency(for: .takeback(progress: progress))
        let envelope = attackEnvelope(progress: progress, attack: attack(for: profile)) * loadGain(for: profile)

        switch profile {
        case .elastic:
            return analogBandTone(
                frequency: frequency,
                envelope: envelope,
                drive: drive(for: profile),
                noiseAmount: 0.018 * progress
            )
        case .storm:
            return stormTone(frequency: frequency * 0.58, envelope: envelope, progress: progress)
        case .airframe:
            return airframeTone(frequency: frequency * 0.82, envelope: envelope, air: 0.18 + (0.10 * progress))
        case .reed:
            return reedTone(frequency: frequency * 0.66, envelope: envelope, bite: 0.22)
        case .pulse:
            return modernPulseTone(frequency: frequency * 1.12, envelope: envelope)
        case .gravity:
            return gravityTone(frequency: frequency * 0.46, envelope: envelope, progress: progress)
        case .glass:
            return pureSynthTone(
                frequency: frequency * 1.34,
                envelope: envelope,
                brightness: brightness(for: profile),
                shimmer: 0.09
            )
        case .rubber:
            return rubberTone(frequency: frequency * 0.72, envelope: envelope, progress: progress)
        }
    }

    private func pauseSample(releaseGain: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let releaseGain = min(max(releaseGain, 0), 1)
        let frequency = pitchFrequency(for: .pause(releaseGain: releaseGain))
        let envelope = topHoldGain(for: profile) * releaseGain

        switch profile {
        case .elastic:
            return analogBandTone(
                frequency: frequency,
                envelope: envelope,
                drive: drive(for: profile),
                noiseAmount: 0
            )
        case .storm:
            return stormTone(frequency: frequency * 0.58, envelope: envelope, progress: 1)
        case .airframe:
            return airframeTone(frequency: frequency * 0.82, envelope: envelope, air: 0.22)
        case .reed:
            return reedTone(frequency: frequency * 0.66, envelope: envelope, bite: 0.16)
        case .pulse:
            return modernPulseTone(frequency: frequency * 1.12, envelope: envelope)
        case .gravity:
            return gravityTone(frequency: frequency * 0.46, envelope: envelope, progress: 1)
        case .glass:
            return pureSynthTone(
                frequency: frequency * 1.34,
                envelope: envelope,
                brightness: brightness(for: profile),
                shimmer: 0.09
            )
        case .rubber:
            return rubberTone(frequency: frequency * 0.72, envelope: envelope, progress: 1)
        }
    }

    private func downswingTrailSample(progress: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let progress = min(max(progress, 0), 1)
        let trailEnvelope = downswingTrailGain(for: profile) * (1 - smoothstep(progress)) * 0.42
        let frequency = exponentialRamp(from: 440, to: 180, progress: progress)

        switch profile {
        case .elastic:
            return flowWaveTone(frequency: frequency * 0.82, envelope: trailEnvelope)
        case .storm:
            return stormTone(frequency: frequency * 0.52, envelope: trailEnvelope * 0.86, progress: 1 - progress)
        case .airframe:
            return airframeTone(frequency: frequency * 0.74, envelope: trailEnvelope, air: 0.26)
        case .reed:
            return reedTone(frequency: frequency * 0.64, envelope: trailEnvelope * 0.72, bite: 0.08)
        case .pulse:
            return modernPulseTone(frequency: frequency * 1.08, envelope: trailEnvelope * 0.66)
        case .gravity:
            return gravityTone(frequency: frequency * 0.42, envelope: trailEnvelope * 0.82, progress: 1 - progress)
        case .glass:
            return pureSynthTone(frequency: frequency * 1.42, envelope: trailEnvelope * 0.62, brightness: 1.22, shimmer: 0.04)
        case .rubber:
            return rubberTone(frequency: frequency * 0.76, envelope: trailEnvelope, progress: 1 - progress)
        }
    }

    private func startAnchorPulseSample(progress: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let progress = min(max(progress, 0), 1)
        let envelope = exp(-18 * progress)
        let body = sin(progress * Double.pi * 18)
        let edge = sin(progress * Double.pi * 31) * 0.28

        return (body + edge) * envelope * anchorPulseGain(for: profile)
    }

    private func topAnchorPulseSample(progress: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let progress = min(max(progress, 0), 1)
        let envelope = exp(-12 * progress)
        let body = sin(progress * Double.pi * 13)
        let lift = sin(progress * Double.pi * 21) * 0.18

        return (body + lift) * envelope * topPulseGain(for: profile)
    }

    private func subdivisionTickSample(progress: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let progress = min(max(progress, 0), 1)
        let envelope = exp(-24 * progress)
        let tick = sin(progress * Double.pi * 29)
        let air = sin(progress * Double.pi * 43) * 0.14

        return (tick + air) * envelope * subdivisionTickGain(for: profile)
    }

    private func impactSample(progress: Double, profile: ElasticSlingshotSoundProfile) -> Double {
        let progress = min(max(progress, 0), 1)
        let parameters = impactParameters(for: profile)
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
        let shapedSample = tanh((primary + body + burst) * parameters.drive) * parameters.gain * tremolo * impactEnvelope(
            progress: progress,
            toneDecayRate: parameters.decayRate
        )

        return impactSoftLimit(shapedSample)
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

    private func stormTone(frequency: Double, envelope: Double, progress: Double) -> Double {
        let adjustedFrequency = max(frequency, 45)
        let phase = voiceState.advanceOscillator(frequency: adjustedFrequency, sampleRate: sampleRate)
        let secondaryPhase = voiceState.advanceSecondary(frequency: adjustedFrequency * 0.49, sampleRate: sampleRate)
        let rumble = sin(phase) * 0.64 + sin(secondaryPhase) * 0.28
        let pressure = voiceState.nextNoiseSample() * 0.035 * min(max(progress, 0), 1)

        return tanh((rumble + pressure) * 1.18) * envelope * 0.23
    }

    private func airframeTone(frequency: Double, envelope: Double, air: Double) -> Double {
        let adjustedFrequency = max(frequency, 90)
        let phase = voiceState.advanceOscillator(frequency: adjustedFrequency, sampleRate: sampleRate)
        let secondaryPhase = voiceState.advanceSecondary(frequency: adjustedFrequency * 1.76, sampleRate: sampleRate)
        let breath = voiceState.nextNoiseSample() * min(max(air, 0), 0.36)
        let lift = sin(phase) * 0.42 + sin(secondaryPhase) * 0.08 + breath

        return tanh(lift) * envelope * 0.18
    }

    private func reedTone(frequency: Double, envelope: Double, bite: Double) -> Double {
        let adjustedFrequency = max(frequency, 80)
        let phase = voiceState.advanceOscillator(frequency: adjustedFrequency, sampleRate: sampleRate)
        let secondaryPhase = voiceState.advanceSecondary(frequency: adjustedFrequency * 2.01, sampleRate: sampleRate)
        let reed = sin(phase) + (sin(phase * 2) * min(max(bite, 0), 0.35)) + (sin(secondaryPhase) * 0.05)

        return tanh(reed * 1.08) * envelope * 0.17
    }

    private func gravityTone(frequency: Double, envelope: Double, progress: Double) -> Double {
        let adjustedFrequency = max(frequency, 42)
        let phase = voiceState.advanceOscillator(frequency: adjustedFrequency, sampleRate: sampleRate)
        let secondaryPhase = voiceState.advanceSecondary(frequency: adjustedFrequency * 1.01, sampleRate: sampleRate)
        let weight = sin(phase) * 0.72 + sin(secondaryPhase) * 0.18
        let air = voiceState.nextNoiseSample() * 0.012 * min(max(progress, 0), 1)

        return tanh((weight + air) * 1.12) * envelope * 0.24
    }

    private func rubberTone(frequency: Double, envelope: Double, progress: Double) -> Double {
        let adjustedFrequency = max(frequency * (1 + (0.035 * sin(progress * Double.pi))), 70)
        let phase = voiceState.advanceOscillator(frequency: adjustedFrequency, sampleRate: sampleRate)
        let secondaryPhase = voiceState.advanceSecondary(frequency: adjustedFrequency * 0.505, sampleRate: sampleRate)
        let stretch = sin(phase) * 0.54 + sin(secondaryPhase) * 0.18

        return tanh(stretch * 1.34) * envelope * 0.21
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
        case .elastic, .rubber:
            return 1.08
        case .storm, .gravity:
            return 1.32
        case .reed:
            return 1.12
        case .airframe, .glass:
            return 0.82
        case .pulse:
            return 1.0
        }
    }

    private func brightness(for profile: ElasticSlingshotSoundProfile) -> Double {
        switch profile {
        case .glass:
            return 1.34
        case .airframe:
            return 1.08
        case .pulse:
            return 1.22
        case .reed:
            return 0.92
        case .elastic, .storm, .gravity, .rubber:
            return 1.0
        }
    }

    private func attack(for profile: ElasticSlingshotSoundProfile) -> Double {
        switch profile {
        case .pulse, .glass:
            return 0.018
        case .airframe:
            return 0.075
        case .gravity, .storm:
            return 0.055
        case .reed:
            return 0.032
        case .elastic, .rubber:
            return 0.045
        }
    }

    private func loadGain(for profile: ElasticSlingshotSoundProfile) -> Double {
        switch profile {
        case .storm, .gravity:
            return 0.92
        case .airframe:
            return 0.78
        case .glass:
            return 0.74
        case .reed:
            return 0.82
        case .pulse:
            return 0.86
        case .elastic, .rubber:
            return 0.88
        }
    }

    private func topHoldGain(for profile: ElasticSlingshotSoundProfile) -> Double {
        switch profile {
        case .storm, .gravity:
            return 0.74
        case .airframe, .glass:
            return 0.58
        case .reed, .pulse:
            return 0.66
        case .elastic, .rubber:
            return 0.70
        }
    }

    private func downswingTrailGain(for profile: ElasticSlingshotSoundProfile) -> Double {
        switch profile {
        case .airframe:
            return 0.62
        case .elastic, .rubber:
            return 0.54
        case .storm, .gravity:
            return 0.44
        case .reed, .glass:
            return 0.36
        case .pulse:
            return 0.30
        }
    }

    private func anchorPulseGain(for profile: ElasticSlingshotSoundProfile) -> Double {
        switch profile {
        case .storm, .gravity:
            return 0.20
        case .airframe, .glass:
            return 0.14
        case .reed, .pulse:
            return 0.16
        case .elastic, .rubber:
            return 0.18
        }
    }

    private func topPulseGain(for profile: ElasticSlingshotSoundProfile) -> Double {
        switch profile {
        case .storm, .gravity:
            return 0.25
        case .airframe, .glass:
            return 0.18
        case .reed, .pulse:
            return 0.21
        case .elastic, .rubber:
            return 0.23
        }
    }

    private func subdivisionTickGain(for profile: ElasticSlingshotSoundProfile) -> Double {
        switch profile {
        case .storm, .gravity:
            return 0.055
        case .airframe, .glass:
            return 0.042
        case .reed, .pulse:
            return 0.048
        case .elastic, .rubber:
            return 0.050
        }
    }

    private func impactParameters(for profile: ElasticSlingshotSoundProfile) -> ElasticSlingshotImpactToneParameters {
        switch profile {
        case .elastic:
            return ElasticSlingshotImpactToneParameters(frequency: 1_720, secondaryMultiplier: 2.28, noiseAmount: 0.08, drive: 1.18, gain: 0.64, decayRate: 24.0, primaryMix: 0.72, secondaryMix: 0.18, bodyMix: 0.08, waveform: .click)
        case .storm:
            return ElasticSlingshotImpactToneParameters(frequency: 620, secondaryMultiplier: 2.12, noiseAmount: 0.18, drive: 1.42, gain: 0.62, decayRate: 18.0, bend: -0.04, primaryMix: 0.68, secondaryMix: 0.10, bodyMix: 0.28, waveform: .click)
        case .airframe:
            return ElasticSlingshotImpactToneParameters(frequency: 2_260, secondaryMultiplier: 1.84, noiseAmount: 0.16, drive: 0.86, gain: 0.52, decayRate: 26.0, primaryMix: 0.58, secondaryMix: 0.12, bodyMix: 0.02, waveform: .noise)
        case .reed:
            return ElasticSlingshotImpactToneParameters(frequency: 1_180, secondaryMultiplier: 2.04, noiseAmount: 0.03, drive: 1.10, gain: 0.54, decayRate: 21.0, primaryMix: 0.64, secondaryMix: 0.18, bodyMix: 0.06, waveform: .square)
        case .pulse:
            return ElasticSlingshotImpactToneParameters(frequency: 1_520, secondaryMultiplier: 2.96, noiseAmount: 0.04, drive: 1.18, gain: 0.58, decayRate: 28.0, tremoloDepth: 0.10, primaryMix: 0.68, secondaryMix: 0.10, bodyMix: 0.08, waveform: .square)
        case .gravity:
            return ElasticSlingshotImpactToneParameters(frequency: 540, secondaryMultiplier: 2.26, noiseAmount: 0.08, drive: 1.36, gain: 0.64, decayRate: 17.0, bend: -0.06, primaryMix: 0.72, secondaryMix: 0.10, bodyMix: 0.30, waveform: .sine)
        case .glass:
            return ElasticSlingshotImpactToneParameters(frequency: 2_760, secondaryMultiplier: 2.18, noiseAmount: 0.02, drive: 0.82, gain: 0.52, decayRate: 31.0, primaryMix: 0.62, secondaryMix: 0.22, bodyMix: 0.02, waveform: .sine)
        case .rubber:
            return ElasticSlingshotImpactToneParameters(frequency: 980, secondaryMultiplier: 2.42, noiseAmount: 0.04, drive: 1.28, gain: 0.60, decayRate: 22.0, bend: 0.08, primaryMix: 0.70, secondaryMix: 0.14, bodyMix: 0.12, waveform: .click)
        }
    }

    private func impactEnvelope(progress: Double, toneDecayRate: Double) -> Double {
        let progress = min(max(progress, 0), 1)
        return exp(-toneDecayRate * progress)
    }

    private func impactSoftLimit(_ sample: Double) -> Double {
        tanh(sample * 1.45) / 1.45
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
    @Published private(set) var statusText = "Idle"

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
        metronomeClickProfile: GarageMetronomeClickProfile,
        guidedClicksEnabled: Bool,
        instrumentMode: GarageTempoInstrumentMode
    ) {
        previewStopTask?.cancel()
        previewStopTask = nil
        fadeStopTask?.cancel()
        fadeStopTask = nil
        guard prepareIfNeeded() else { return }
        renderState.start(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            metronomeClickProfile: metronomeClickProfile,
            guidedClicksEnabled: guidedClicksEnabled,
            instrumentMode: instrumentMode,
            mode: .continuous
        )
        playbackState = .playing
        statusText = "Running"
    }

    func playOneCycle(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        metronomeClickProfile: GarageMetronomeClickProfile,
        guidedClicksEnabled: Bool,
        instrumentMode: GarageTempoInstrumentMode
    ) {
        previewStopTask?.cancel()
        previewStopTask = nil
        fadeStopTask?.cancel()
        fadeStopTask = nil
        guard prepareIfNeeded() else { return }
        renderState.silence()
        print("[TempoAudio] preview profile=\(soundProfile.rawValue)")
        renderState.start(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            metronomeClickProfile: metronomeClickProfile,
            guidedClicksEnabled: guidedClicksEnabled,
            instrumentMode: instrumentMode,
            mode: .oneCycle
        )
        playbackState = .playing
        statusText = "Previewing"

        let previewDuration = instrumentMode == .metronome
            ? 0.30
            : recipe.swingDuration(for: beatsPerMinute) + elasticSlingshotImpactDuration + 0.08
        previewStopTask = Task { [weak self] in
            let nanoseconds = UInt64(max(previewDuration, 0.1) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard Task.isCancelled == false else { return }
            self?.finishImpactPreview()
        }
    }

    func stop() {
        previewStopTask?.cancel()
        previewStopTask = nil
        fadeStopTask?.cancel()
        renderState.stop()
        playbackState = .stopped
        statusText = "Stopping"

        fadeStopTask = Task { [weak self] in
            let nanoseconds = UInt64(elasticSlingshotStopFadeDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard Task.isCancelled == false else { return }
            self?.finishStopAfterFade()
        }
    }

    private func finishStopAfterFade() {
        renderState.silence()
        audioEngine.pause()
        fadeStopTask = nil
        statusText = "Stopped"
    }

    private func finishImpactPreview() {
        renderState.silence()
        audioEngine.pause()
        previewStopTask = nil
        playbackState = .stopped
        statusText = "Stopped"
    }

    func update(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        metronomeClickProfile: GarageMetronomeClickProfile,
        guidedClicksEnabled: Bool,
        instrumentMode: GarageTempoInstrumentMode
    ) {
        renderState.update(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            metronomeClickProfile: metronomeClickProfile,
            guidedClicksEnabled: guidedClicksEnabled,
            instrumentMode: instrumentMode
        )
    }

    @discardableResult
    private func prepareIfNeeded() -> Bool {
        guard isPrepared == false else {
            if audioEngine.isRunning == false {
                do {
                    try audioEngine.start()
                } catch {
                    statusText = "Engine restart failed: \(error.localizedDescription)"
                    return false
                }
            }
            return true
        }

        let session = AVAudioSession.sharedInstance()
        // Swing Capture records with the microphone; keep this category compatible with capture so the tempo engine keeps playing.
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            statusText = "Audio session failed: \(error.localizedDescription)"
            return false
        }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            statusText = "Audio format unavailable"
            return false
        }

        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            statusText = "Engine start failed: \(error.localizedDescription)"
            return false
        }
        isPrepared = true
        statusText = "Ready"
        return true
    }

    var outputRouteText: String {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portName)
        return outputs.isEmpty ? "No output route" : outputs.joined(separator: ", ")
    }
}
