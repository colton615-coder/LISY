import AVFoundation
import Combine
import Foundation

struct ElasticSlingshotRecipe: Equatable {
    var takeawayPercent: Double = 70
    var pausePercent: Double = 10
    var downswingPercent: Double = 20
    var restInterval: TimeInterval = 1.15

    var normalizedTakeaway: Double {
        normalizedPhaseValues.takeaway
    }

    var normalizedPause: Double {
        normalizedPhaseValues.pause
    }

    var normalizedDownswing: Double {
        normalizedPhaseValues.downswing
    }

    var displayText: String {
        "\(Int(takeawayPercent.rounded())) / \(Int(pausePercent.rounded())) / \(Int(downswingPercent.rounded()))"
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

    mutating func rebalance(changedPhase: ElasticSlingshotRecipePhase, value: Double) {
        let clampedValue = min(max(value, 0), 100)
        let remaining = 100 - clampedValue

        switch changedPhase {
        case .takeaway:
            let otherTotal = max(pausePercent + downswingPercent, 1)
            takeawayPercent = clampedValue
            pausePercent = remaining * pausePercent / otherTotal
            downswingPercent = remaining * downswingPercent / otherTotal
        case .pause:
            let otherTotal = max(takeawayPercent + downswingPercent, 1)
            pausePercent = clampedValue
            takeawayPercent = remaining * takeawayPercent / otherTotal
            downswingPercent = remaining * downswingPercent / otherTotal
        case .downswing:
            let otherTotal = max(takeawayPercent + pausePercent, 1)
            downswingPercent = clampedValue
            takeawayPercent = remaining * takeawayPercent / otherTotal
            pausePercent = remaining * pausePercent / otherTotal
        }
    }

    private var normalizedPhaseValues: (takeaway: Double, pause: Double, downswing: Double) {
        let total = max(takeawayPercent + pausePercent + downswingPercent, 1)
        return (
            takeaway: takeawayPercent / total,
            pause: pausePercent / total,
            downswing: downswingPercent / total
        )
    }
}

enum ElasticSlingshotRecipePhase: String, CaseIterable, Identifiable {
    case takeaway = "Takeaway"
    case pause = "Pause"
    case downswing = "Downswing"

    var id: String { rawValue }
}

enum ElasticSlingshotPlaybackState: Equatable {
    case stopped
    case playing
}

enum ElasticSlingshotSoundProfile: String, CaseIterable, Identifiable {
    case analogBand
    case pureSynth
    case ratchet
    case whip
    case percussive
    case sonar
    case elastic
    case tensionSnap
    case ping
    case drip
    case clack
    case swoosh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .analogBand:
            return "Analog Band"
        case .pureSynth:
            return "Pure Synth"
        case .ratchet:
            return "Ratchet"
        case .whip:
            return "Whip"
        case .percussive:
            return "Percussive"
        case .sonar:
            return "Sonar"
        case .elastic:
            return "Elastic"
        case .tensionSnap:
            return "Tension Snap"
        case .ping:
            return "Ping"
        case .drip:
            return "Drip"
        case .clack:
            return "Clack"
        case .swoosh:
            return "Swoosh"
        }
    }
}

private struct ElasticSlingshotRenderConfiguration {
    var beatsPerMinute: Double
    var recipe: ElasticSlingshotRecipe
    var baseFrame: AVAudioFramePosition
    var isPlaying: Bool
}

private final class ElasticSlingshotRenderState {
    private let lock = NSLock()
    private let sampleRate: Double
    private var configuration = ElasticSlingshotRenderConfiguration(
        beatsPerMinute: 72,
        recipe: ElasticSlingshotRecipe(),
        baseFrame: 0,
        isPlaying: false
    )
    private var latestFrame: AVAudioFramePosition = 0
    private var oscillatorPhase = 0.0
    private var noiseSeed: UInt64 = 0x9E37_79B9_7F4A_7C15

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func update(beatsPerMinute: Double, recipe: ElasticSlingshotRecipe) {
        lock.lock()
        configuration.beatsPerMinute = beatsPerMinute
        configuration.recipe = recipe
        lock.unlock()
    }

    func start(beatsPerMinute: Double, recipe: ElasticSlingshotRecipe) {
        lock.lock()
        configuration = ElasticSlingshotRenderConfiguration(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            baseFrame: max(latestFrame, 0) + frames(for: 0.05),
            isPlaying: true
        )
        oscillatorPhase = 0
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
                for frameOffset in 0..<outputCount {
                    data[frameOffset] = 0
                }
                continue
            }

            for frameOffset in 0..<outputCount {
                let absoluteFrame = startFrame + AVAudioFramePosition(frameOffset)
                let sample = sampleValue(at: absoluteFrame, configuration: snapshot)
                data[frameOffset] = Float(max(min(sample, 0.82), -0.82))
            }
        }

        return noErr
    }

    private func sampleValue(at frame: AVAudioFramePosition, configuration: ElasticSlingshotRenderConfiguration) -> Double {
        let relativeFrame = max(frame - configuration.baseFrame, 0)
        let swingDuration = configuration.recipe.swingDuration(for: configuration.beatsPerMinute)
        let takeawayDuration = configuration.recipe.takeawayDuration(for: configuration.beatsPerMinute)
        let pauseDuration = configuration.recipe.pauseDuration(for: configuration.beatsPerMinute)
        let downswingDuration = configuration.recipe.downswingDuration(for: configuration.beatsPerMinute)
        let loopDuration = max(swingDuration + configuration.recipe.restInterval, 0.1)
        let elapsed = Double(relativeFrame) / sampleRate
        let loopElapsed = elapsed.truncatingRemainder(dividingBy: loopDuration)

        if loopElapsed < takeawayDuration {
            return takeawaySample(progress: loopElapsed / max(takeawayDuration, 0.01))
        }

        if loopElapsed < takeawayDuration + pauseDuration {
            return 0
        }

        if loopElapsed < takeawayDuration + pauseDuration + downswingDuration {
            let localElapsed = loopElapsed - takeawayDuration - pauseDuration
            return impactSample(progress: localElapsed / max(downswingDuration, 0.01))
        }

        return 0
    }

    private func takeawaySample(progress: Double) -> Double {
        let clampedProgress = min(max(progress, 0), 1)
        let frequency = 68 + (92 * pow(clampedProgress, 1.35))
        let intensity = 0.08 + (0.2 * clampedProgress)
        let grittyLayer = sin(oscillatorPhase * 0.49) * 0.35
        let noise = nextNoiseSample() * 0.035 * clampedProgress

        oscillatorPhase += 2 * Double.pi * frequency / sampleRate
        if oscillatorPhase > 2 * Double.pi {
            oscillatorPhase -= 2 * Double.pi
        }

        let wave = sin(oscillatorPhase) + grittyLayer
        return (wave * intensity + noise) * smoothEnvelope(progress: clampedProgress)
    }

    private func impactSample(progress: Double) -> Double {
        let clampedProgress = min(max(progress, 0), 1)
        let snapEnvelope = exp(-10 * clampedProgress)
        let thudEnvelope = exp(-5 * clampedProgress)
        let swoosh = nextNoiseSample() * snapEnvelope * 0.42
        let thudFrequency = 54.0

        oscillatorPhase += 2 * Double.pi * thudFrequency / sampleRate
        if oscillatorPhase > 2 * Double.pi {
            oscillatorPhase -= 2 * Double.pi
        }

        return swoosh + sin(oscillatorPhase) * thudEnvelope * 0.52
    }

    private func smoothEnvelope(progress: Double) -> Double {
        let attack = min(progress / 0.08, 1)
        let release = min((1 - progress) / 0.12, 1)
        return min(attack, release)
    }

    private func nextNoiseSample() -> Double {
        noiseSeed = 2862933555777941757 &* noiseSeed &+ 3037000493
        let normalized = Double((noiseSeed >> 33) & 0xFFFF) / Double(UInt16.max)
        return (normalized * 2) - 1
    }

    private func frames(for interval: TimeInterval) -> AVAudioFramePosition {
        AVAudioFramePosition((interval * sampleRate).rounded())
    }
}

@MainActor
final class ElasticSlingshotAudioEngine: ObservableObject {
    @Published private(set) var playbackState: ElasticSlingshotPlaybackState = .stopped
    @Published private(set) var currentCycle = 0

    private let audioEngine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let renderState: ElasticSlingshotRenderState
    private let sourceNode: AVAudioSourceNode
    private var isPrepared = false

    init() {
        let renderState = ElasticSlingshotRenderState(sampleRate: sampleRate)
        self.renderState = renderState
        self.sourceNode = AVAudioSourceNode { _, timestamp, frameCount, audioBufferList in
            renderState.render(timestamp: timestamp, frameCount: frameCount, audioBufferList: audioBufferList)
        }
    }

    func start(beatsPerMinute: Double, recipe: ElasticSlingshotRecipe) {
        prepareIfNeeded()
        renderState.start(beatsPerMinute: beatsPerMinute, recipe: recipe)
        playbackState = .playing
    }

    func stop() {
        renderState.stop()
        audioEngine.pause()
        playbackState = .stopped
        currentCycle = 0
    }

    func update(beatsPerMinute: Double, recipe: ElasticSlingshotRecipe) {
        renderState.update(beatsPerMinute: beatsPerMinute, recipe: recipe)
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
