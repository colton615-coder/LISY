import AVFoundation
import Combine
import Foundation

private let elasticSlingshotStopFadeDuration: TimeInterval = 0.09
private let elasticSlingshotImpactDuration: TimeInterval = 0.08

struct ElasticSlingshotRecipe: Equatable {
    var tempoRatio: ElasticSlingshotTempoRatio = .tour
    var restInterval: TimeInterval = 5
    var followThroughDuration: TimeInterval = 0.42
    var subdivisionMultiplier = GarageSlowTempoLogic.defaultSubdivisionMultiplier

    var impactDuration: TimeInterval {
        elasticSlingshotImpactDuration
    }

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
        guidedMotionDuration(for: beatsPerMinute) + restInterval
    }

    func guidedMotionDuration(for beatsPerMinute: Double) -> TimeInterval {
        swingDuration(for: beatsPerMinute) + elasticSlingshotImpactDuration + followThroughDuration
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
    case woodblock
    case rimshot
    case leatherSnap
    case stoneKnock
    case glassTick
    case crispMarker
    case lowPunch
    case digitalTick
    case softAir
    case brightSignal
    case dryClave
    case hardwoodClick
    case rangeStick
    case mutedTap
    case quietBlock
    case glassPing
    case impactKnock
    case digitalPulse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .woodblock: "Woodblock"
        case .rimshot: "Rimshot"
        case .leatherSnap: "Muted Skin"
        case .stoneKnock: "Deep Knock"
        case .glassTick: "Glass Tick"
        case .crispMarker: "Crisp Marker"
        case .lowPunch: "Low Punch"
        case .digitalTick: "Hat Tick"
        case .softAir: "Soft Air"
        case .brightSignal: "Bright Signal"
        case .dryClave: "Dry Clave"
        case .hardwoodClick: "Hardwood Click"
        case .rangeStick: "Range Stick"
        case .mutedTap: "Muted Tap"
        case .quietBlock: "Quiet Block"
        case .glassPing: "Glass Ping"
        case .impactKnock: "Impact Knock"
        case .digitalPulse: "Digital Pulse"
        }
    }

    var character: String {
        switch self {
        case .woodblock: "Warm, dry, natural"
        case .rimshot: "Sharp, bright, precise"
        case .leatherSnap: "Tight, muted, tactile"
        case .stoneKnock: "Solid, low, compact"
        case .glassTick: "Light, bright, brittle"
        case .crispMarker: "Short, clear beat marker"
        case .lowPunch: "Deep, firm speaker presence"
        case .digitalTick: "Dry metallic hi-hat tick"
        case .softAir: "Light and unobtrusive"
        case .brightSignal: "Clear, projecting marker"
        case .dryClave: "Dry, tight, immediate"
        case .hardwoodClick: "Solid wood, compact attack"
        case .rangeStick: "Hard stick, clean contact"
        case .mutedTap: "Soft skin, short response"
        case .quietBlock: "Low-fatigue wood marker"
        case .glassPing: "Bright, clear accent"
        case .impactKnock: "Firm, focused impact"
        case .digitalPulse: "Short electronic pulse"
        }
    }

    var assetName: String {
        switch self {
        case .woodblock: "woodblock"
        case .rimshot: "rimshot"
        case .leatherSnap: "leather_snap"
        case .stoneKnock: "stone_knock"
        case .glassTick: "glass_tick"
        case .crispMarker: "crisp_marker"
        case .lowPunch: "low_punch"
        case .digitalTick: "digital_tick"
        case .softAir: "soft_air"
        case .brightSignal: "bright_signal"
        case .dryClave: "dry_clave"
        case .hardwoodClick: "hardwood_click"
        case .rangeStick: "range_stick"
        case .mutedTap: "muted_tap"
        case .quietBlock: "quiet_block"
        case .glassPing: "glass_ping"
        case .impactKnock: "impact_knock"
        case .digitalPulse: "digital_pulse"
        }
    }

    static let crispMarkers: [Self] = [.crispMarker, .dryClave, .hardwoodClick, .rangeStick, .woodblock, .rimshot]
    static let softPractice: [Self] = [.softAir, .mutedTap, .quietBlock, .leatherSnap]
    static let signalAccents: [Self] = [.brightSignal, .glassPing, .glassTick, .impactKnock, .stoneKnock, .lowPunch]
    static let digitalSynthetic: [Self] = [.digitalPulse, .digitalTick]

    static func migrated(from rawValue: String) -> Self {
        if let profile = Self(rawValue: rawValue) {
            return profile
        }

        return switch rawValue {
        case "hardwood": .woodblock
        case "ball", "rim": .rimshot
        case "steel": .brightSignal
        case "leather": .leatherSnap
        case "stone": .stoneKnock
        case "pulse": .digitalTick
        case "glass": .glassTick
        case "signal": .crispMarker
        case "core": .lowPunch
        default: .woodblock
        }
    }
}

enum GarageGuidedSwingProfile: String, CaseIterable, Identifiable {
    case tourWhip
    case heavySteel
    case glassLine
    case airCut
    case digitalVector
    case rangeWood

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tourWhip: "Guided Swing"
        case .heavySteel: "Guided Swing"
        case .glassLine: "Guided Swing"
        case .airCut: "Guided Swing"
        case .digitalVector: "Guided Swing"
        case .rangeWood: "Guided Swing"
        }
    }

    var character: String {
        switch self {
        case .tourWhip: "Quiet pressure rise, clean transition, controlled impact."
        case .heavySteel: "Quiet pressure rise, clean transition, controlled impact."
        case .glassLine: "Quiet pressure rise, clean transition, controlled impact."
        case .airCut: "Quiet pressure rise, clean transition, controlled impact."
        case .digitalVector: "Quiet pressure rise, clean transition, controlled impact."
        case .rangeWood: "Quiet pressure rise, clean transition, controlled impact."
        }
    }

    var engineProfile: TempoSoundIdentityProfile {
        switch self {
        case .tourWhip: .tourWhip
        case .heavySteel: .heavySteel
        case .glassLine: .glassLine
        case .airCut: .airCut
        case .digitalVector: .digitalVector
        case .rangeWood: .rangeWood
        }
    }

    static let listeningOrder: [Self] = [.tourWhip]

    static func migrated(from rawValue: String) -> Self {
        switch rawValue {
        case Self.tourWhip.rawValue:
            return .tourWhip
        default:
            return .tourWhip
        }
    }
}

enum TempoSoundPhase: Hashable {
    case build
    case top
    case downswing
    case impact
    case tail
}

enum TempoSoundPitchBehavior: Equatable {
    case rising(from: Double, to: Double)
    case descending(from: Double, to: Double)
    case stepped(values: [Double])
    case fixed(Double)
    case silent
}

struct TempoSoundPhasePlan: Equatable {
    let assetName: String?
    let assetGain: Double
    let synthesisGain: Double
    let pitch: TempoSoundPitchBehavior
    let attack: Double
    let release: Double
    let silenceWindow: ClosedRange<Double>?
}

struct TempoSoundEventPlan: Equatable {
    let phases: [TempoSoundPhase: TempoSoundPhasePlan]
    let outputGain: Double

    subscript(_ phase: TempoSoundPhase) -> TempoSoundPhasePlan {
        phases[phase] ?? TempoSoundPhasePlan(
            assetName: nil,
            assetGain: 0,
            synthesisGain: 0,
            pitch: .silent,
            attack: 0,
            release: 0,
            silenceWindow: nil
        )
    }
}

enum TempoSoundIdentityProfile: String, CaseIterable, Identifiable {
    case tourWhip
    case heavySteel
    case glassLine
    case airCut
    case digitalVector
    case rangeWood

    var id: String { rawValue }

    var eventPlan: TempoSoundEventPlan {
        switch self {
        case .tourWhip, .heavySteel, .glassLine, .airCut, .digitalVector, .rangeWood:
            return TempoSoundEventPlan(
                phases: [
                    .build: .init(assetName: nil, assetGain: 0, synthesisGain: 1, pitch: .rising(from: 220, to: 330), attack: 0.12, release: 0.24, silenceWindow: nil),
                    .top: .init(assetName: nil, assetGain: 0, synthesisGain: 0, pitch: .silent, attack: 0, release: 0, silenceWindow: 0...1),
                    .downswing: .init(assetName: nil, assetGain: 0, synthesisGain: 1, pitch: .rising(from: 360, to: 540), attack: 0.02, release: 0.20, silenceWindow: nil),
                    .impact: .init(assetName: nil, assetGain: 0, synthesisGain: 1, pitch: .fixed(420), attack: 0, release: 0.78, silenceWindow: nil),
                    .tail: .init(assetName: nil, assetGain: 0, synthesisGain: 0, pitch: .silent, attack: 0, release: 0, silenceWindow: 0...1)
                ],
                outputGain: 0.96
            )
        }
    }
}

typealias ElasticSlingshotSoundProfile = TempoSoundIdentityProfile

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
    case pause(progress: Double)
    case downswing(progress: Double)
    case impact(progress: Double)
    case followThrough(progress: Double)
    case loopDelay
    case finished
}

private struct ElasticSlingshotRenderConfiguration {
    var beatsPerMinute: Double
    var recipe: ElasticSlingshotRecipe
    var soundProfile: ElasticSlingshotSoundProfile
    var metronomeStartProfile: GarageMetronomeClickProfile
    var metronomeImpactProfile: GarageMetronomeClickProfile
    var outputRouteFamily: GarageTempoOutputRouteFamily
    var pendingOutputRouteFamily: GarageTempoOutputRouteFamily?
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
            return slowTempoLogic.anchorInterval * 4
        }

        switch mode {
        case .continuous:
            return recipe.loopDuration(for: beatsPerMinute)
        case .oneCycle:
            return recipe.guidedMotionDuration(for: beatsPerMinute)
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

private enum GarageTempoOutputRouteFamily {
    case speaker
    case headphones
}

private struct GarageMetronomeSampleLibrary {
    let samplesByProfile: [GarageMetronomeClickProfile: [Float]]

    static func load() -> Self {
        let samples = GarageMetronomeClickProfile.allCases.reduce(into: [GarageMetronomeClickProfile: [Float]]()) { result, profile in
            guard let url = sampleURL(for: profile) else {
                debugLog("Missing bundled sample: \(profile.assetName).wav. Falling back to synthesized click.")
                return
            }
            guard let sample = loadSample(at: url) else {
                debugLog("Could not decode bundled sample: \(profile.assetName).wav. Falling back to synthesized click.")
                return
            }
            result[profile] = sample
        }
        debugLog("Loaded \(samples.count)/\(GarageMetronomeClickProfile.allCases.count) bundled samples.")
        return Self(samplesByProfile: samples)
    }

    private static func sampleURL(for profile: GarageMetronomeClickProfile) -> URL? {
        Bundle.main.url(
            forResource: profile.assetName,
            withExtension: "wav",
            subdirectory: "Metronome_Audio"
        ) ?? Bundle.main.url(
            forResource: profile.assetName,
            withExtension: "wav",
            subdirectory: "Garage/Metronome_Audio"
        ) ?? Bundle.main.url(forResource: profile.assetName, withExtension: "wav")
    }

    private static func loadSample(at url: URL) -> [Float]? {
        do {
            let file = try AVAudioFile(
                forReading: url,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
            let capacity = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: capacity) else {
                return nil
            }
            try file.read(into: buffer)
            guard let channelData = buffer.floatChannelData?[0] else {
                return nil
            }
            return Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        } catch {
            return nil
        }
    }

    private static func debugLog(_ message: String) {
#if DEBUG
        print("[MetronomeAudio] \(message)")
#endif
    }
}

private struct TempoSoundAssetLibrary {
    let samplesByName: [String: [Float]]

    static func load() -> Self {
        let names = Set(
            TempoSoundIdentityProfile.allCases.flatMap { identity in
                identity.eventPlan.phases.values.compactMap(\.assetName)
            }
        )
        let samples = names.reduce(into: [String: [Float]]()) { result, name in
            guard let url = sampleURL(for: name), let sample = loadSample(at: url) else {
#if DEBUG
                print("[TempoAudio] Missing guided identity asset: \(name).wav")
#endif
                return
            }
            result[name] = sample
        }
#if DEBUG
        print("[TempoAudio] Loaded \(samples.count)/\(names.count) guided identity assets.")
#endif
        return Self(samplesByName: samples)
    }

    private static func sampleURL(for name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Metronome_Audio")
            ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Garage/Metronome_Audio")
            ?? Bundle.main.url(forResource: name, withExtension: "wav")
    }

    private static func loadSample(at url: URL) -> [Float]? {
        do {
            let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
            let capacity = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: capacity) else {
                return nil
            }
            try file.read(into: buffer)
            guard let channelData = buffer.floatChannelData?[0] else { return nil }
            return Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        } catch {
            return nil
        }
    }
}

private final class ElasticSlingshotRenderState {
    private let lock = NSLock()
    private let sampleRate: Double
    private let metronomeSamples: [GarageMetronomeClickProfile: [Float]]
    private let identitySamples: [String: [Float]]
    private var configuration = ElasticSlingshotRenderConfiguration(
        beatsPerMinute: 75,
        recipe: ElasticSlingshotRecipe(),
        soundProfile: .tourWhip,
        metronomeStartProfile: .woodblock,
        metronomeImpactProfile: .brightSignal,
        outputRouteFamily: .headphones,
        pendingOutputRouteFamily: nil,
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
    private var currentLoopProgress: Double = 0.0
    private var voiceState = ElasticSlingshotVoiceState()
    private var appliedResetToken = 0

    init(
        sampleRate: Double,
        metronomeSamples: [GarageMetronomeClickProfile: [Float]],
        identitySamples: [String: [Float]]
    ) {
        self.sampleRate = sampleRate
        self.metronomeSamples = metronomeSamples
        self.identitySamples = identitySamples
    }

    func getLoopProgress() -> Double {
        lock.lock()
        defer { lock.unlock() }
        return currentLoopProgress
    }

    func setOutputRouteFamily(_ routeFamily: GarageTempoOutputRouteFamily) {
        lock.lock()
        if configuration.pendingOutputRouteFamily == routeFamily {
            lock.unlock()
            return
        }
        if configuration.outputRouteFamily == routeFamily {
            configuration.pendingOutputRouteFamily = nil
            lock.unlock()
            return
        }
        if configuration.isPlaying, configuration.instrumentMode == .metronome {
            configuration.pendingOutputRouteFamily = routeFamily
        } else {
            configuration.outputRouteFamily = routeFamily
            configuration.pendingOutputRouteFamily = nil
        }
        lock.unlock()
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
        lock.lock()
        let timingChanged = configuration.beatsPerMinute != beatsPerMinute
            || configuration.recipe != recipe
            || configuration.instrumentMode != instrumentMode
        let voiceChanged = configuration.soundProfile != soundProfile
            || configuration.metronomeStartProfile != metronomeStartProfile
            || configuration.metronomeImpactProfile != metronomeImpactProfile
        if configuration.isPlaying, timingChanged {
            let oldTotalFrames = max(frames(for: configuration.totalDuration), 1)
            let oldLoopFrames = max(frames(for: configuration.loopDuration), oldTotalFrames)
            let currentRelativeFrame = max(latestFrame - configuration.baseFrame, 0)

            // Capture the exact location in the active cycle.
            let currentCycleFrame = currentRelativeFrame % oldLoopFrames
            let currentProgressFraction = Double(currentCycleFrame) / Double(oldLoopFrames)

            // Compute the new loop frame boundaries ahead of assignment.
            let newSlowTempoLogic = recipe.slowTempoLogic(for: beatsPerMinute)
            let newLoopDuration = instrumentMode == .metronome
                ? newSlowTempoLogic.anchorInterval * 4
                : recipe.loopDuration(for: beatsPerMinute)
            let newLoopFrames = max(AVAudioFramePosition((newLoopDuration * sampleRate).rounded()), 1)

            // Shift the base frame so the active cycle keeps the same progress.
            let newRelativeCycleFrame = AVAudioFramePosition((currentProgressFraction * Double(newLoopFrames)).rounded())
            configuration.baseFrame = latestFrame - newRelativeCycleFrame
            configuration.alignsBaseFrameOnNextRender = false
        }
        configuration.beatsPerMinute = beatsPerMinute
        configuration.recipe = recipe
        configuration.soundProfile = soundProfile
        configuration.metronomeStartProfile = metronomeStartProfile
        configuration.metronomeImpactProfile = metronomeImpactProfile
        configuration.guidedClicksEnabled = guidedClicksEnabled
        configuration.instrumentMode = instrumentMode
        if configuration.isPlaying, timingChanged || voiceChanged {
            configuration.resetToken += 1
        }
        lock.unlock()
    }

    func start(
        beatsPerMinute: Double,
        recipe: ElasticSlingshotRecipe,
        soundProfile: ElasticSlingshotSoundProfile,
        metronomeStartProfile: GarageMetronomeClickProfile,
        metronomeImpactProfile: GarageMetronomeClickProfile,
        guidedClicksEnabled: Bool,
        instrumentMode: GarageTempoInstrumentMode,
        mode: ElasticSlingshotPlaybackMode
    ) {
        lock.lock()
        configuration = ElasticSlingshotRenderConfiguration(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            metronomeStartProfile: metronomeStartProfile,
            metronomeImpactProfile: metronomeImpactProfile,
            outputRouteFamily: configuration.outputRouteFamily,
            pendingOutputRouteFamily: configuration.pendingOutputRouteFamily,
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
        if let pendingRoute = configuration.pendingOutputRouteFamily {
            configuration.outputRouteFamily = pendingRoute
            configuration.pendingOutputRouteFamily = nil
        }
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
        if let pendingRoute = configuration.pendingOutputRouteFamily,
           configuration.instrumentMode == .metronome {
            let relativeStartFrame = max(startFrame - configuration.baseFrame, 0)
            let beatFrames = max(frames(for: configuration.slowTempoLogic.anchorInterval), 1)
            let frameInsideBeat = relativeStartFrame % beatFrames
            if frameInsideBeat == 0 || frameInsideBeat + AVAudioFramePosition(frameCount) >= beatFrames {
                configuration.outputRouteFamily = pendingRoute
                configuration.pendingOutputRouteFamily = nil
            }
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

        if snapshot.isPlaying {
            let lastRenderedFrame = startFrame + AVAudioFramePosition(max(outputCount - 1, 0))
            updatePlaybackProgress(at: lastRenderedFrame, configuration: snapshot)
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
        if configuration.instrumentMode == .metronome {
            rawSample = 0
        } else {
            switch phase(for: relativeFrame, configuration: configuration) {
            case let .takeback(progress):
                rawSample = guidedIdentitySample(phase: .build, progress: progress, duration: configuration.takebackDuration, profile: configuration.soundProfile)
            case let .pause(progress):
                rawSample = guidedIdentitySample(phase: .top, progress: progress, duration: configuration.pauseDuration, profile: configuration.soundProfile)
            case let .downswing(progress):
                rawSample = guidedIdentitySample(phase: .downswing, progress: progress, duration: configuration.downswingDuration, profile: configuration.soundProfile)
            case let .impact(progress):
                rawSample = guidedIdentitySample(phase: .impact, progress: progress, duration: elasticSlingshotImpactDuration, profile: configuration.soundProfile)
            case let .followThrough(progress):
                rawSample = guidedIdentitySample(phase: .tail, progress: progress, duration: configuration.recipe.followThroughDuration, profile: configuration.soundProfile)
            case .loopDelay, .finished:
                rawSample = 0
            }
        }

        let guideSample = slowTempoGuideSample(at: relativeFrame, configuration: configuration)
        return (rawSample + guideSample) * playbackEnvelope(at: frame, configuration: configuration)
    }

    private func updatePlaybackProgress(
        at frame: AVAudioFramePosition,
        configuration: ElasticSlingshotRenderConfiguration
    ) {
        let relativeFrame = max(frame - configuration.baseFrame, 0)
        let totalFrames = max(frames(for: configuration.totalDuration), 1)
        let loopFrames = max(frames(for: configuration.loopDuration), totalFrames)
        let cycleFrame = configuration.mode == .continuous ? (relativeFrame % loopFrames) : relativeFrame

        lock.lock()
        currentLoopProgress = Double(cycleFrame) / Double(loopFrames)
        lock.unlock()
    }

    private func phase(for relativeFrame: AVAudioFramePosition, configuration: ElasticSlingshotRenderConfiguration) -> ElasticSlingshotPhase {
        let totalFrames = max(frames(for: configuration.totalDuration), 1)
        let loopFrames = max(frames(for: configuration.loopDuration), totalFrames)
        let impactDurationFrames = max(frames(for: elasticSlingshotImpactDuration), 1)

        let followThroughFrames = max(frames(for: configuration.recipe.followThroughDuration), 1)
        if configuration.mode == .oneCycle, relativeFrame >= totalFrames + impactDurationFrames + followThroughFrames {
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
            let pauseFrame = cycleFrame - takebackFrames
            return .pause(progress: Double(pauseFrame) / Double(max(pauseFrames, 1)))
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

        let followThroughEndFrame = totalFrames + impactDurationFrames + followThroughFrames
        if cycleFrame < followThroughEndFrame {
            let followThroughFrame = cycleFrame - totalFrames - impactDurationFrames
            return .followThrough(progress: Double(followThroughFrame) / Double(followThroughFrames))
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
            let beatInterval = configuration.slowTempoLogic.anchorInterval
            let beatFrames = max(frames(for: beatInterval), 1)

            // Align each click to the recurring beat grid.
            let clickFrame = cycleFrame % beatFrames

            let regularTick = metronomeGuideSample(
                cycleFrame: clickFrame,
                eventFrame: 0,
                duration: 0.034,
                gain: 1,
                profile: configuration.metronomeStartProfile,
                routeFamily: configuration.outputRouteFamily
            )
            return regularTick
        }

        guard configuration.guidedClicksEnabled, cycleFrame < totalFrames else { return 0 }

        let beatFrames = max(frames(for: configuration.slowTempoLogic.anchorInterval), 1)
        let clickFrame = cycleFrame % beatFrames
        return metronomeGuideSample(
            cycleFrame: clickFrame,
            eventFrame: beatFrames / 2,
            duration: 0.028,
            gain: 0.32,
            profile: configuration.metronomeStartProfile,
            routeFamily: configuration.outputRouteFamily
        )

    }

    private func metronomeGuideSample(
        cycleFrame: AVAudioFramePosition,
        eventFrame: AVAudioFramePosition,
        duration: TimeInterval,
        gain: Double,
        profile: GarageMetronomeClickProfile,
        routeFamily: GarageTempoOutputRouteFamily
    ) -> Double {
        let sampleFrame = cycleFrame - eventFrame
        if sampleFrame >= 0,
           let sample = metronomeSamples[profile],
           Int(sampleFrame) < sample.count {
            let routeGain = routeFamily == .speaker ? 1.0 : 0.92
            return Double(sample[Int(sampleFrame)]) * gain * routeGain
        }

        let pulseFrames = max(frames(for: duration), 1)
        if let progress = eventProgress(
            cycleFrame: cycleFrame,
            eventFrame: eventFrame,
            durationFrames: pulseFrames
        ) {
            return metronomeClickSample(
                progress: progress,
                profile: profile,
                routeFamily: routeFamily
            ) * gain
        }

        return 0
    }

    private func metronomeClickSample(
        progress: Double,
        profile: GarageMetronomeClickProfile,
        routeFamily: GarageTempoOutputRouteFamily
    ) -> Double {
        let progress = min(max(progress, 0), 1)
        let noise = voiceState.nextNoiseSample()
        let speaker = routeFamily == .speaker
        let phase = progress * Double.pi
        let onset = exp(-95 * progress)
        let sample: Double

        switch profile {
        case .woodblock:
            let body = sin(phase * (speaker ? 10 : 13))
            let hollow = sin(phase * (speaker ? 22 : 27))
            sample = tanh((body * 0.82) + (hollow * 0.16) + (onset * 0.12)) * exp(-30 * progress) * 0.54
        case .rimshot:
            let rim = sin(phase * (speaker ? 38 : 46))
            let crack = noise * exp(-120 * progress)
            sample = tanh((rim * 0.66) + (crack * 0.42) + (onset * 0.25)) * exp(-58 * progress) * 0.50
        case .leatherSnap:
            let muted = tanh(sin(phase * (speaker ? 15 : 18)) * 0.72)
            sample = tanh((muted * 0.58) + (noise * 0.28) + (onset * 0.14)) * exp(-72 * progress) * 0.58
        case .stoneKnock:
            let low = sin(phase * (speaker ? 7 : 9))
            let grit = tanh(noise * 0.34)
            sample = tanh((low * 0.92) + (grit * 0.16) + (onset * 0.10)) * exp(-25 * progress) * 0.60
        case .glassTick:
            let glass = sin(phase * (speaker ? 58 : 72))
            let shimmer = sin(phase * (speaker ? 93 : 116))
            sample = ((glass * 0.70) + (shimmer * 0.22) + (onset * 0.16)) * exp(-62 * progress) * 0.48
        case .crispMarker:
            let marker = sin(phase * (speaker ? 31 : 36))
            sample = tanh((marker * 0.52) + (onset * 0.58)) * exp(-88 * progress) * 0.54
        case .lowPunch:
            let punch = sin(phase * (speaker ? 6 : 8))
            let upper = sin(phase * 17)
            sample = tanh((punch * 1.02) + (upper * 0.12) + (onset * 0.12)) * exp(-22 * progress) * 0.62
        case .digitalTick:
            let square = sin(phase * (speaker ? 24 : 29)) >= 0 ? 0.58 : -0.58
            let bit = sin(phase * 61)
            sample = tanh((square * 0.72) + (bit * 0.16) + (onset * 0.30)) * exp(-76 * progress) * 0.50
        case .softAir:
            let air = noise * exp(-42 * progress)
            let tone = sin(phase * (speaker ? 42 : 55))
            sample = tanh((air * 0.52) + (tone * 0.22) + (onset * 0.12)) * exp(-38 * progress) * 0.55
        case .brightSignal:
            let signal = sin(phase * (speaker ? 45 : 52))
            let overtone = sin(phase * (speaker ? 68 : 82))
            sample = tanh((signal * 0.64) + (overtone * 0.26) + (onset * 0.20)) * exp(-48 * progress) * 0.50
        case .dryClave, .hardwoodClick, .rangeStick, .quietBlock:
            let wood = sin(phase * (speaker ? 20 : 26))
            sample = tanh((wood * 0.64) + (onset * 0.44)) * exp(-76 * progress) * 0.52
        case .mutedTap:
            sample = tanh((noise * 0.34) + (onset * 0.38)) * exp(-68 * progress) * 0.50
        case .glassPing:
            let ping = sin(phase * (speaker ? 64 : 82))
            sample = ((ping * 0.72) + (onset * 0.22)) * exp(-56 * progress) * 0.48
        case .impactKnock:
            let knock = sin(phase * (speaker ? 8 : 11))
            sample = tanh((knock * 0.82) + (onset * 0.24)) * exp(-36 * progress) * 0.56
        case .digitalPulse:
            let pulse = sin(phase * (speaker ? 42 : 54)) >= 0 ? 0.62 : -0.62
            sample = tanh((pulse * 0.70) + (onset * 0.34)) * exp(-88 * progress) * 0.48
        }

        return tanh(sample * 1.28) / 1.28
    }

    private func eventProgress(
        cycleFrame: AVAudioFramePosition,
        eventFrame: AVAudioFramePosition,
        durationFrames: AVAudioFramePosition
    ) -> Double? {
        guard cycleFrame >= eventFrame, cycleFrame < eventFrame + durationFrames else { return nil }
        return Double(cycleFrame - eventFrame) / Double(max(durationFrames, 1))
    }

    private func guidedIdentitySample(
        phase: TempoSoundPhase,
        progress: Double,
        duration: TimeInterval,
        profile: TempoSoundIdentityProfile
    ) -> Double {
        let progress = min(max(progress, 0), 1)
        let plan = profile.eventPlan
        let phasePlan = plan[phase]
        if phasePlan.silenceWindow?.contains(progress) == true {
            return 0
        }

        let envelope = identityEnvelope(
            progress: progress,
            attack: phasePlan.attack,
            release: phasePlan.release
        )
        let asset = identityAssetSample(
            name: phasePlan.assetName,
            phase: phase,
            progress: progress,
            duration: duration
        ) * phasePlan.assetGain
        let generated = guidedTrainerGeneratedSample(
            phase: phase,
            progress: progress,
            pitch: phasePlan.pitch
        )

        return impactSoftLimit((asset + (generated * phasePlan.synthesisGain)) * envelope * plan.outputGain)
    }

    private func identityAssetSample(
        name: String?,
        phase: TempoSoundPhase,
        progress: Double,
        duration: TimeInterval
    ) -> Double {
        guard let name, let sample = identitySamples[name], sample.isEmpty == false else { return 0 }
        let index: Int
        if phase == .top || phase == .impact {
            // Preserve the native attack of short landmarks instead of stretching them across the phase.
            let elapsedFrames = Int(progress * duration * sampleRate)
            guard elapsedFrames < sample.count else { return 0 }
            index = elapsedFrames
        } else {
            index = min(Int(progress * Double(sample.count)), sample.count - 1)
        }
        return Double(sample[index])
    }

    private func identityEnvelope(progress: Double, attack: Double, release: Double) -> Double {
        let attackGain = attack > 0 ? min(progress / attack, 1) : 1
        let releaseStart = max(1 - release, 0)
        let releaseGain = release > 0 && progress > releaseStart
            ? max((1 - progress) / release, 0)
            : 1
        return min(attackGain, releaseGain)
    }

    private func identityFrequency(_ behavior: TempoSoundPitchBehavior, progress: Double) -> Double {
        switch behavior {
        case let .rising(from, to), let .descending(from, to):
            return exponentialRamp(from: from, to: to, progress: progress)
        case let .stepped(values):
            guard values.isEmpty == false else { return 0 }
            let index = min(Int(progress * Double(values.count)), values.count - 1)
            return values[index]
        case let .fixed(value):
            return value
        case .silent:
            return 0
        }
    }

    private func guidedTrainerGeneratedSample(
        phase: TempoSoundPhase,
        progress: Double,
        pitch: TempoSoundPitchBehavior
    ) -> Double {
        let frequency = identityFrequency(pitch, progress: progress)
        switch phase {
        case .build:
            return guidedLoadTone(frequency: frequency, progress: progress)
        case .top:
            return 0
        case .downswing:
            return guidedReleaseTone(frequency: frequency, progress: progress)
        case .impact:
            return guidedImpactMarkerTone(frequency: frequency, progress: progress)
        case .tail:
            return 0
        }
    }

    private func guidedLoadTone(frequency: Double, progress: Double) -> Double {
        let phase = voiceState.advanceOscillator(frequency: frequency, sampleRate: sampleRate)
        let lowerPhase = voiceState.advanceSecondary(frequency: frequency * 0.5, sampleRate: sampleRate)
        let lift = smoothstep(progress)
        let tone = (sin(phase) * 0.22) + (sin(lowerPhase) * 0.10)

        return tanh(tone) * lift * 0.34
    }

    private func guidedReleaseTone(frequency: Double, progress: Double) -> Double {
        let phase = voiceState.advanceOscillator(frequency: frequency, sampleRate: sampleRate)
        let upperPhase = voiceState.advanceSecondary(frequency: frequency * 1.5, sampleRate: sampleRate)
        let acceleration = smoothstep(progress)
        let tone = (sin(phase) * 0.24) + (sin(upperPhase) * 0.06)

        return tanh(tone) * (0.35 + (0.65 * acceleration)) * 0.40
    }

    private func guidedImpactMarkerTone(frequency: Double, progress: Double) -> Double {
        let phase = voiceState.advanceOscillator(frequency: frequency, sampleRate: sampleRate)
        let lowerPhase = voiceState.advanceSecondary(frequency: frequency * 0.5, sampleRate: sampleRate)
        let decay = exp(-38 * progress)
        let transient = voiceState.nextNoiseSample() * 0.08 * exp(-95 * progress)
        let body = (sin(phase) * 0.42) + (sin(lowerPhase) * 0.18)

        return tanh(body + transient) * decay * 0.56
    }

    private func exponentialRamp(from start: Double, to end: Double, progress: Double) -> Double {
        let progress = min(max(progress, 0), 1)
        return start * pow(end / start, progress)
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

    private func impactSoftLimit(_ sample: Double) -> Double {
        tanh(sample * 1.35) * 0.855
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
    private var routeChangeCancellable: AnyCancellable?

    init() {
        let sampleLibrary = GarageMetronomeSampleLibrary.load()
        let identityLibrary = TempoSoundAssetLibrary.load()
        let renderState = ElasticSlingshotRenderState(
            sampleRate: sampleRate,
            metronomeSamples: sampleLibrary.samplesByProfile,
            identitySamples: identityLibrary.samplesByName
        )
        self.renderState = renderState
        self.sourceNode = AVAudioSourceNode { _, timestamp, frameCount, audioBufferList in
            renderState.render(timestamp: timestamp, frameCount: frameCount, audioBufferList: audioBufferList)
        }
        updateOutputRouteFamily()
        routeChangeCancellable = NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateOutputRouteFamily()
                }
            }
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
        previewStopTask?.cancel()
        previewStopTask = nil
        fadeStopTask?.cancel()
        fadeStopTask = nil
        guard prepareIfNeeded() else { return }
        renderState.start(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            metronomeStartProfile: metronomeStartProfile,
            metronomeImpactProfile: metronomeImpactProfile,
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
        metronomeStartProfile: GarageMetronomeClickProfile,
        metronomeImpactProfile: GarageMetronomeClickProfile,
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
            metronomeStartProfile: metronomeStartProfile,
            metronomeImpactProfile: metronomeImpactProfile,
            guidedClicksEnabled: guidedClicksEnabled,
            instrumentMode: instrumentMode,
            mode: .oneCycle
        )
        playbackState = .playing
        statusText = "Previewing"

        let previewDuration = instrumentMode == .metronome
            ? 0.30
            : recipe.guidedMotionDuration(for: beatsPerMinute) + 0.08
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
        metronomeStartProfile: GarageMetronomeClickProfile,
        metronomeImpactProfile: GarageMetronomeClickProfile,
        guidedClicksEnabled: Bool,
        instrumentMode: GarageTempoInstrumentMode
    ) {
        renderState.update(
            beatsPerMinute: beatsPerMinute,
            recipe: recipe,
            soundProfile: soundProfile,
            metronomeStartProfile: metronomeStartProfile,
            metronomeImpactProfile: metronomeImpactProfile,
            guidedClicksEnabled: guidedClicksEnabled,
            instrumentMode: instrumentMode
        )
    }

    func currentPlaybackProgress() -> Double {
        renderState.getLoopProgress()
    }

    private func updateOutputRouteFamily() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let usesBuiltInSpeaker = outputs.contains { $0.portType == .builtInSpeaker }
        renderState.setOutputRouteFamily(usesBuiltInSpeaker ? .speaker : .headphones)
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
            updateOutputRouteFamily()
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

extension ElasticSlingshotAudioEngine: GarageTempoAudioControlling {}
