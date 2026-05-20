import Foundation
import AVFoundation
import Combine
import SwiftUI

private enum GarageTempoRunState: Equatable {
    case ready
    case running
    case paused

    var label: String {
        switch self {
        case .ready:
            return "Ready"
        case .running:
            return "Running"
        case .paused:
            return "Paused"
        }
    }
}

private enum GarageTempoLoopPhase: Equatable {
    case setupWait
    case backswing
    case downswing
    case reset

    var label: String {
        switch self {
        case .setupWait:
            return "Setup"
        case .backswing:
            return "Backswing"
        case .downswing:
            return "Downswing"
        case .reset:
            return "Reset"
        }
    }
}

private enum GarageTempoProfile: String, CaseIterable, Identifiable {
    case fullSwing
    case shortGame
    case putting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullSwing:
            return "Full Swing"
        case .shortGame:
            return "Short Game"
        case .putting:
            return "Putting"
        }
    }

    var tempoDefaults: (beatsPerMinute: Double, setupDelay: Double) {
        switch self {
        case .fullSwing:
            return (beatsPerMinute: 72, setupDelay: 5)
        case .shortGame:
            return (beatsPerMinute: 66, setupDelay: 4)
        case .putting:
            return (beatsPerMinute: 78, setupDelay: 3)
        }
    }
}

private enum GarageTempoCue {
    case start
    case top
    case impact
}

private struct GarageTempoConfiguration: Equatable {
    var beatsPerMinute: Double = 72
    var setupDelay: Double = 5
    var audioEnabled = true
    var hapticsEnabled = false

    var backswingRatio: Double {
        0.75
    }

    var downswingRatio: Double {
        0.25
    }

    var swingDuration: TimeInterval {
        (60 / beatsPerMinute) * 4
    }

    var backswingDuration: TimeInterval {
        swingDuration * backswingRatio
    }

    var downswingDuration: TimeInterval {
        swingDuration * downswingRatio
    }

    var loopDuration: TimeInterval {
        setupDelay + swingDuration
    }

    var bpmText: String {
        "\(Int(beatsPerMinute.rounded()))"
    }

    var ratioText: String {
        "3:1"
    }

    var setupDelayText: String {
        "\(Int(setupDelay.rounded()))s"
    }

    var cueSummaryText: String {
        switch audioEnabled {
        case true:
            return "Audio only"
        case false:
            return "Silent cues"
        }
    }
}

private struct GarageTempoAudioEvent {
    let frequency: Double
    let frameTime: AVAudioFramePosition
    let isAnchor: Bool
}

private struct GarageTempoToneVoice {
    let frequency: Double
    let startFrame: AVAudioFramePosition
    let durationFrames: AVAudioFramePosition
    let gain: Float
}

private final class GarageTempoToneRenderState {
    private let lock = NSLock()
    private var scheduledEvents: [GarageTempoAudioEvent] = []
    private var activeVoices: [GarageTempoToneVoice] = []
    private var latestFrame: AVAudioFramePosition = 0
    private let sampleRate: Double

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func scheduleTone(frequency: Double, at frame: AVAudioFramePosition, isAnchor: Bool) {
        lock.lock()
        scheduledEvents.append(GarageTempoAudioEvent(frequency: frequency, frameTime: frame, isAnchor: isAnchor))
        scheduledEvents.sort { $0.frameTime < $1.frameTime }
        lock.unlock()
    }

    func reset() {
        lock.lock()
        scheduledEvents.removeAll()
        activeVoices.removeAll()
        lock.unlock()
    }

    func currentFrame() -> AVAudioFramePosition {
        lock.lock()
        let frame = latestFrame
        lock.unlock()
        return frame
    }

    func render(timestamp: UnsafePointer<AudioTimeStamp>, frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let startFrame = AVAudioFramePosition(timestamp.pointee.mSampleTime)
        let outputCount = Int(frameCount)

        lock.lock()
        latestFrame = startFrame + AVAudioFramePosition(frameCount)
        var events = scheduledEvents
        var voices = activeVoices
        lock.unlock()

        for buffer in abl {
            guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            for frameOffset in 0..<outputCount {
                let absoluteFrame = startFrame + AVAudioFramePosition(frameOffset)

                while let nextEvent = events.first, nextEvent.frameTime <= absoluteFrame {
                    let duration = AVAudioFramePosition(sampleRate * (nextEvent.isAnchor ? 0.18 : 0.14))
                    voices.append(
                        GarageTempoToneVoice(
                            frequency: nextEvent.frequency,
                            startFrame: nextEvent.frameTime,
                            durationFrames: duration,
                            gain: nextEvent.isAnchor ? 0.26 : 0.34
                        )
                    )
                    events.removeFirst()
                }

                var mixedSample: Float = 0
                for voice in voices {
                    let voiceFrame = absoluteFrame - voice.startFrame
                    guard voiceFrame >= 0, voiceFrame < voice.durationFrames else { continue }

                    let progress = Double(voiceFrame) / Double(max(voice.durationFrames, 1))
                    let attack = min(progress / 0.035, 1)
                    let envelope = pow(attack, 2) * exp(-5.0 * progress)
                    let sampleTime = Double(voiceFrame) / sampleRate
                    let wave = sin(2.0 * Double.pi * voice.frequency * sampleTime)
                    mixedSample += Float(wave * envelope) * voice.gain
                }

                data[frameOffset] = max(min(mixedSample, 0.82), -0.82)
            }
        }

        voices.removeAll { voice in
            startFrame + AVAudioFramePosition(frameCount) > voice.startFrame + voice.durationFrames
        }

        lock.lock()
        scheduledEvents = events
        activeVoices = voices
        lock.unlock()

        return noErr
    }
}

private final class GarageTempoToneSynthesizer {
    let sourceNode: AVAudioSourceNode
    private let renderState: GarageTempoToneRenderState

    init(sampleRate: Double) {
        let renderState = GarageTempoToneRenderState(sampleRate: sampleRate)
        self.renderState = renderState
        self.sourceNode = AVAudioSourceNode { _, timestamp, frameCount, audioBufferList in
            renderState.render(timestamp: timestamp, frameCount: frameCount, audioBufferList: audioBufferList)
        }
    }

    func scheduleTone(frequency: Double, at frame: AVAudioFramePosition, isAnchor: Bool) {
        renderState.scheduleTone(frequency: frequency, at: frame, isAnchor: isAnchor)
    }

    func reset() {
        renderState.reset()
    }

    func currentFrame() -> AVAudioFramePosition {
        renderState.currentFrame()
    }
}

@MainActor
private final class GarageTempoAudioClock {
    private let audioEngine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private let synthesizer: GarageTempoToneSynthesizer
    private var isPrepared = false
    private var sequenceBaseFrame: AVAudioFramePosition = 0

    init() {
        synthesizer = GarageTempoToneSynthesizer(sampleRate: sampleRate)
    }

    func startSession() {
        prepareIfNeeded()
    }

    func stop() {
        synthesizer.reset()
        audioEngine.pause()
    }

    func resetEvents() {
        synthesizer.reset()
        sequenceBaseFrame = max(synthesizer.currentFrame(), 0) + frames(for: 0.08)
    }

    func scheduleCycle(configuration: GarageTempoConfiguration, cycleIndex: Int) {
        prepareIfNeeded()
        guard configuration.audioEnabled else { return }

        let cycleStartFrame = anchorFrame(forCycle: cycleIndex, configuration: configuration)
        let addressFrame = cycleStartFrame + frames(for: configuration.setupDelay)
        let topFrame = addressFrame + frames(for: configuration.backswingDuration)
        let impactFrame = topFrame + frames(for: configuration.downswingDuration)

        synthesizer.scheduleTone(frequency: toneProfile(for: .start).frequency, at: addressFrame, isAnchor: true)
        synthesizer.scheduleTone(frequency: toneProfile(for: .top).frequency, at: topFrame, isAnchor: false)
        synthesizer.scheduleTone(frequency: toneProfile(for: .impact).frequency, at: impactFrame, isAnchor: false)
    }

    func playImmediate(_ cue: GarageTempoCue) {
        prepareIfNeeded()
        let frame = max(synthesizer.currentFrame(), 0) + frames(for: 0.03)
        let profile = toneProfile(for: cue)
        synthesizer.scheduleTone(frequency: profile.frequency, at: frame, isAnchor: cue == .start)
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

        audioEngine.attach(synthesizer.sourceNode)
        audioEngine.connect(synthesizer.sourceNode, to: audioEngine.mainMixerNode, format: format)
        try? audioEngine.start()
        isPrepared = true
    }

    private func anchorFrame(forCycle cycleIndex: Int, configuration: GarageTempoConfiguration) -> AVAudioFramePosition {
        sequenceBaseFrame + frames(for: configuration.loopDuration * Double(cycleIndex))
    }

    private func frames(for interval: TimeInterval) -> AVAudioFramePosition {
        AVAudioFramePosition((interval * sampleRate).rounded())
    }

    private func toneProfile(for cue: GarageTempoCue) -> (frequency: Double, duration: Double, gain: Float) {
        switch cue {
        case .start:
            return (frequency: 392.00, duration: 0.18, gain: 0.26)
        case .top:
            return (frequency: 587.33, duration: 0.14, gain: 0.34)
        case .impact:
            return (frequency: 880.00, duration: 0.14, gain: 0.38)
        }
    }
}

@MainActor
private final class GarageTempoEngine: NSObject, ObservableObject {
    @Published private(set) var state: GarageTempoRunState = .ready
    @Published private(set) var cycleCount = 0
    @Published private(set) var impactPulseID = 0
    @Published private(set) var configuration = GarageTempoConfiguration()
    @Published private(set) var loopPhase: GarageTempoLoopPhase = .setupWait

    private var visualTicker: DispatchSourceTimer?
    private var loopStartDate: Date?
    private var preciseProgress: Double = 0
    private var preciseLoopProgress: TimeInterval = 0
    private var pausedLoopProgress: TimeInterval = 0
    private let audioClock = GarageTempoAudioClock()
    private var didPlayStartCue = false
    private var didPlayTopCue = false
    private var didPlayImpactCue = false
    private var nextScheduledCycleIndex = 0
    private var audioCycleBaseIndex = 0
    private let scheduledCycleLookahead = 10

    var phaseLabel: String {
        switch state {
        case .ready:
            return "Setup"
        case .paused:
            return "Paused"
        case .running:
            return loopPhase.label
        }
    }

    func start(configuration: GarageTempoConfiguration) {
        var nextConfiguration = configuration
        nextConfiguration.hapticsEnabled = false
        self.configuration = nextConfiguration
        preciseProgress = 0
        preciseLoopProgress = 0
        pausedLoopProgress = 0
        cycleCount = 0
        loopPhase = .setupWait
        resetCueFlags()
        state = .running
        loopStartDate = .now
        if nextConfiguration.audioEnabled {
            audioClock.startSession()
            audioClock.resetEvents()
            audioCycleBaseIndex = cycleCount
            scheduleAudioCycles(startingAt: 0)
        }
        startVisualTicker()
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        loopStartDate = Date().addingTimeInterval(-pausedLoopProgress)
        restoreCueFlagsForResume()
        if configuration.audioEnabled {
            audioClock.startSession()
            audioClock.resetEvents()
            audioCycleBaseIndex = cycleCount
            let resumeCycle = cycleCount
            scheduleAudioCycles(startingAt: resumeCycle)
        }
        startVisualTicker()
    }

    func pause() {
        guard state == .running else { return }
        pausedLoopProgress = preciseLoopProgress
        state = .paused
        stopVisualTicker()
        audioClock.stop()
    }

    func stop() {
        state = .ready
        preciseProgress = 0
        preciseLoopProgress = 0
        pausedLoopProgress = 0
        cycleCount = 0
        loopPhase = .setupWait
        loopStartDate = nil
        resetCueFlags()
        nextScheduledCycleIndex = 0
        audioCycleBaseIndex = 0
        stopVisualTicker()
        audioClock.stop()
    }

    func stopForDisappear() {
        stop()
    }

    func updateConfiguration(_ nextConfiguration: GarageTempoConfiguration) {
        let currentLoopProgress = preciseLoopProgress
        let normalizedLoopProgress = configuration.loopDuration > 0 ? currentLoopProgress / configuration.loopDuration : 0
        var sanitizedConfiguration = nextConfiguration
        sanitizedConfiguration.hapticsEnabled = false
        configuration = sanitizedConfiguration

        if sanitizedConfiguration.audioEnabled == false {
            audioClock.stop()
        } else if state == .running || state == .paused {
            audioClock.startSession()
            audioClock.resetEvents()
            audioCycleBaseIndex = cycleCount
            scheduleAudioCycles(startingAt: cycleCount)
        }

        if state == .running {
            let nextLoopProgress = normalizedLoopProgress * sanitizedConfiguration.loopDuration
            preciseLoopProgress = min(nextLoopProgress, sanitizedConfiguration.loopDuration)
            loopStartDate = Date().addingTimeInterval(-preciseLoopProgress)
            restoreCueFlagsForCurrentPhase()
        } else if state == .paused {
            pausedLoopProgress = min(normalizedLoopProgress * sanitizedConfiguration.loopDuration, sanitizedConfiguration.loopDuration)
            preciseLoopProgress = pausedLoopProgress
            restoreCueFlagsForCurrentPhase()
        }
    }

    func triggerImpactPulse() {
        impactPulseID += 1
        playAudioCue(.impact)
    }

    func visualProgress(at date: Date) -> Double {
        guard state != .ready else { return 0 }
        let elapsed = visualLoopProgress(at: date)
        return swingProgress(for: elapsed)
    }

    private func startVisualTicker() {
        stopVisualTicker()
        let ticker = DispatchSource.makeTimerSource(queue: .main)
        ticker.schedule(deadline: .now(), repeating: .milliseconds(33), leeway: .milliseconds(6))
        ticker.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.tick()
            }
        }
        visualTicker = ticker
        ticker.resume()
    }

    private func stopVisualTicker() {
        visualTicker?.cancel()
        visualTicker = nil
    }

    private func tick(now: Date = .now) {
        guard state == .running, let loopStartDate else { return }

        let elapsed = now.timeIntervalSince(loopStartDate)
        let duration = max(configuration.loopDuration, 0.1)
        let elapsedCycles = Int(elapsed / duration)
        let cycleElapsed = elapsed.truncatingRemainder(dividingBy: duration)
        let nextPhase = phase(for: cycleElapsed)
        let nextProgress = swingProgress(for: cycleElapsed)

        if elapsedCycles > cycleCount {
            cycleCount = elapsedCycles
            resetCueFlags()
            impactPulseID += 1
        }

        preciseLoopProgress = cycleElapsed
        preciseProgress = nextProgress
        loopPhase = nextPhase
        updateCueFlagsForVisualState(phase: nextPhase, progress: nextProgress)
        scheduleMoreAudioCyclesIfNeeded()
    }

    private func resetCueFlags() {
        didPlayStartCue = false
        didPlayTopCue = false
        didPlayImpactCue = false
    }

    private func restoreCueFlagsForResume() {
        restoreCueFlagsForCurrentPhase()
    }

    private func restoreCueFlagsForCurrentPhase() {
        let phase = phase(for: preciseLoopProgress)
        let currentProgress = swingProgress(for: preciseLoopProgress)
        loopPhase = phase
        preciseProgress = currentProgress
        didPlayStartCue = phase != .setupWait
        didPlayTopCue = currentProgress >= configuration.backswingRatio
        didPlayImpactCue = false
    }

    private func updateCueFlagsForVisualState(phase: GarageTempoLoopPhase, progress: Double) {
        if phase != .setupWait {
            didPlayStartCue = true
        }

        if phase == .downswing, progress >= configuration.backswingRatio {
            didPlayTopCue = true
        }

        if phase == .reset || progress >= 0.995 {
            didPlayImpactCue = true
        }
    }

    private func phase(for loopElapsed: TimeInterval) -> GarageTempoLoopPhase {
        if loopElapsed < configuration.setupDelay {
            return .setupWait
        }

        let swingElapsed = loopElapsed - configuration.setupDelay
        if swingElapsed < configuration.backswingDuration {
            return .backswing
        }

        if swingElapsed < configuration.swingDuration {
            return .downswing
        }

        return .reset
    }

    private func swingProgress(for loopElapsed: TimeInterval) -> Double {
        guard loopElapsed >= configuration.setupDelay else {
            return 0
        }

        let swingElapsed = min(max(loopElapsed - configuration.setupDelay, 0), configuration.swingDuration)
        return min(max(swingElapsed / configuration.swingDuration, 0), 1)
    }

    private func visualLoopProgress(at date: Date) -> TimeInterval {
        switch state {
        case .ready:
            return 0
        case .paused:
            return pausedLoopProgress
        case .running:
            guard let loopStartDate else { return 0 }
            let elapsed = date.timeIntervalSince(loopStartDate)
            let duration = max(configuration.loopDuration, 0.1)
            return elapsed.truncatingRemainder(dividingBy: duration)
        }
    }

    private func scheduleAudioCycles(startingAt cycleIndex: Int) {
        nextScheduledCycleIndex = max(cycleIndex, 0)
        for _ in 0..<scheduledCycleLookahead {
            audioClock.scheduleCycle(configuration: configuration, cycleIndex: nextScheduledCycleIndex - audioCycleBaseIndex)
            nextScheduledCycleIndex += 1
        }
    }

    private func scheduleMoreAudioCyclesIfNeeded() {
        guard configuration.audioEnabled,
              nextScheduledCycleIndex - cycleCount <= 4 else { return }

        for _ in 0..<scheduledCycleLookahead {
            audioClock.scheduleCycle(configuration: configuration, cycleIndex: nextScheduledCycleIndex - audioCycleBaseIndex)
            nextScheduledCycleIndex += 1
        }
    }

    private func playAudioCue(_ cue: GarageTempoCue) {
        guard configuration.audioEnabled else { return }
        audioClock.startSession()
        audioClock.playImmediate(cue)
    }
}

@MainActor
struct GarageTempoBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = GarageTempoEngine()
    @State private var configuration = GarageTempoConfiguration()
    @State private var profile: GarageTempoProfile = .fullSwing
    @State private var showsMoreControls = false

    var body: some View {
        ZStack {
            GarageTempoCockpitBackground()

            GeometryReader { proxy in
                let horizontalPadding: CGFloat = 12
                let bottomPadding = max(proxy.safeAreaInsets.bottom - 12, 4)

                TimelineView(.animation) { timeline in
                    let visualProgress = engine.visualProgress(at: timeline.date)

                    Group {
                        switch engine.state {
                        case .ready:
                            GarageTempoReadyLayout(
                                size: proxy.size,
                                configuration: $configuration,
                                profile: $profile,
                                progress: visualProgress,
                                loopPhase: engine.loopPhase,
                                phaseLabel: engine.phaseLabel,
                                cycleCount: engine.cycleCount,
                                hapticsEnabled: configuration.hapticsEnabled,
                                onBack: closeBuilder,
                                onConfigurationChange: engine.updateConfiguration,
                                onStart: handlePrimaryAction,
                                onMore: { showsMoreControls = true }
                            )

                        case .running:
                            GarageTempoActiveLayout(
                                size: proxy.size,
                                configuration: $configuration,
                                profile: $profile,
                                progress: visualProgress,
                                loopPhase: engine.loopPhase,
                                phaseLabel: engine.phaseLabel,
                                cycleCount: engine.cycleCount,
                                impactPulseID: engine.impactPulseID,
                                hapticsEnabled: configuration.hapticsEnabled,
                                onBack: closeBuilder,
                                onConfigurationChange: engine.updateConfiguration,
                                onPause: handlePrimaryAction,
                                onStop: resetSet
                            )

                        case .paused:
                            GarageTempoPausedLayout(
                                size: proxy.size,
                                configuration: $configuration,
                                profile: $profile,
                                progress: visualProgress,
                                loopPhase: engine.loopPhase,
                                phaseLabel: engine.phaseLabel,
                                cycleCount: engine.cycleCount,
                                impactPulseID: engine.impactPulseID,
                                hapticsEnabled: configuration.hapticsEnabled,
                                onBack: closeBuilder,
                                onConfigurationChange: engine.updateConfiguration,
                                onResume: handlePrimaryAction,
                                onStop: resetSet,
                                onAdjust: { showsMoreControls = true }
                            )
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, bottomPadding)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: engine.state)
            }
        }
        .sheet(isPresented: $showsMoreControls) {
            GarageTempoMoreControlsSheet(
                configuration: $configuration,
                profile: $profile,
                engineState: engine.state,
                onConfigurationChange: engine.updateConfiguration,
                onReset: resetSet,
                onPulse: engine.triggerImpactPulse
            )
            .presentationDetents([.height(420), .medium])
            .presentationDragIndicator(.visible)
        }
        .onDisappear {
            engine.stopForDisappear()
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func closeBuilder() {
        engine.stopForDisappear()
        dismiss()
    }

    private func handlePrimaryAction() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            switch engine.state {
            case .running:
                engine.pause()
            case .paused:
                engine.resume()
            case .ready:
                engine.start(configuration: configuration)
            }
        }
    }

    private func resetSet() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            engine.stop()
        }
    }

}

private struct GarageTempoReadyLayout: View {
    let size: CGSize
    @Binding var configuration: GarageTempoConfiguration
    @Binding var profile: GarageTempoProfile
    let progress: Double
    let loopPhase: GarageTempoLoopPhase
    let phaseLabel: String
    let cycleCount: Int
    let hapticsEnabled: Bool
    let onBack: () -> Void
    let onConfigurationChange: (GarageTempoConfiguration) -> Void
    let onStart: () -> Void
    let onMore: () -> Void

    private var dialSize: CGFloat {
        garageTempoInstrumentSize(for: size)
    }

    var body: some View {
        VStack(spacing: 9) {
            GarageTempoTopBar(profile: profile, hapticsEnabled: hapticsEnabled, onBack: onBack)
                .frame(height: 40)

            GarageTempoHeroReadout(
                configuration: configuration,
                runState: .ready,
                phaseLabel: phaseLabel,
                cycleCount: cycleCount
            )
            .frame(height: 76)

            GarageTempoDialCard(
                configuration: configuration,
                progress: progress,
                loopPhase: loopPhase,
                phaseLabel: phaseLabel,
                runState: .ready,
                cycleCount: cycleCount,
                impactPulseID: 0
            )
            .frame(width: dialSize, height: dialSize)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 6)

            GarageTempoSetupPanel(
                configuration: $configuration,
                profile: $profile,
                hapticsEnabled: hapticsEnabled,
                onConfigurationChange: onConfigurationChange
            )

            GarageTempoActionBar(
                primaryTitle: "Start",
                primaryIcon: "play.fill",
                isPrimaryActive: true,
                showsStop: false,
                showsMore: true,
                hapticsEnabled: hapticsEnabled,
                onPrimaryAction: onStart,
                onStop: {},
                onMore: onMore
            )
        }
    }
}

private struct GarageTempoActiveLayout: View {
    let size: CGSize
    @Binding var configuration: GarageTempoConfiguration
    @Binding var profile: GarageTempoProfile
    let progress: Double
    let loopPhase: GarageTempoLoopPhase
    let phaseLabel: String
    let cycleCount: Int
    let impactPulseID: Int
    let hapticsEnabled: Bool
    let onBack: () -> Void
    let onConfigurationChange: (GarageTempoConfiguration) -> Void
    let onPause: () -> Void
    let onStop: () -> Void

    private var dialSize: CGFloat {
        garageTempoInstrumentSize(for: size)
    }

    var body: some View {
        VStack(spacing: 9) {
            GarageTempoTopBar(profile: profile, hapticsEnabled: hapticsEnabled, onBack: onBack)
                .frame(height: 40)

            GarageTempoExecutionReadout(
                configuration: configuration,
                runState: .running,
                phaseLabel: phaseLabel,
                cycleCount: cycleCount,
                isActive: true
            )
            .frame(height: 86)

            GarageTempoDialCard(
                configuration: configuration,
                progress: progress,
                loopPhase: loopPhase,
                phaseLabel: phaseLabel,
                runState: .running,
                cycleCount: cycleCount,
                impactPulseID: impactPulseID
            )
            .frame(width: dialSize, height: dialSize)
            .frame(maxWidth: .infinity)

            GarageTempoLiveTuneDock(
                configuration: $configuration,
                profile: $profile,
                hapticsEnabled: hapticsEnabled,
                onConfigurationChange: onConfigurationChange
            )

            Spacer(minLength: 6)

            GarageTempoActionBar(
                primaryTitle: "Pause",
                primaryIcon: "pause.fill",
                isPrimaryActive: false,
                stopTitle: "Stop",
                showsStop: true,
                showsMore: false,
                hapticsEnabled: hapticsEnabled,
                onPrimaryAction: onPause,
                onStop: onStop,
                onMore: {}
            )
        }
    }
}

private struct GarageTempoPausedLayout: View {
    let size: CGSize
    @Binding var configuration: GarageTempoConfiguration
    @Binding var profile: GarageTempoProfile
    let progress: Double
    let loopPhase: GarageTempoLoopPhase
    let phaseLabel: String
    let cycleCount: Int
    let impactPulseID: Int
    let hapticsEnabled: Bool
    let onBack: () -> Void
    let onConfigurationChange: (GarageTempoConfiguration) -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onAdjust: () -> Void

    private var dialSize: CGFloat {
        garageTempoInstrumentSize(for: size)
    }

    var body: some View {
        VStack(spacing: 10) {
            GarageTempoTopBar(profile: profile, hapticsEnabled: hapticsEnabled, onBack: onBack)
                .frame(height: 44)

            GarageTempoPausedStatus(
                configuration: configuration,
                phaseLabel: phaseLabel,
                cycleCount: cycleCount
            )

            GarageTempoDialCard(
                configuration: configuration,
                progress: progress,
                loopPhase: loopPhase,
                phaseLabel: phaseLabel,
                runState: .paused,
                cycleCount: cycleCount,
                impactPulseID: impactPulseID
            )
            .frame(width: dialSize, height: dialSize)
            .frame(maxWidth: .infinity)

            GarageTempoSetupPanel(
                configuration: $configuration,
                profile: $profile,
                hapticsEnabled: hapticsEnabled,
                onConfigurationChange: onConfigurationChange
            )

            GarageTempoActionBar(
                primaryTitle: "Resume",
                primaryIcon: "play.fill",
                isPrimaryActive: true,
                stopTitle: "Stop",
                moreTitle: "More",
                showsStop: true,
                showsMore: true,
                hapticsEnabled: hapticsEnabled,
                onPrimaryAction: onResume,
                onStop: onStop,
                onMore: onAdjust
            )
        }
    }
}

private func garageTempoInstrumentSize(for size: CGSize) -> CGFloat {
    min(size.width - 24, size.height * 0.39)
}

private struct GarageTempoExecutionReadout: View {
    let configuration: GarageTempoConfiguration
    let runState: GarageTempoRunState
    let phaseLabel: String
    let cycleCount: Int
    let isActive: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 7) {
                Text(configuration.bpmText)
                    .font(.system(size: isActive ? 58 : 44, weight: .black, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("BPM")
                    .font(.system(size: isActive ? 14 : 12, weight: .black, design: .rounded))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .padding(.bottom, isActive ? 9 : 7)
            }
            .layoutPriority(1)

            VStack(spacing: 8) {
                GarageTempoReadoutChip(title: "CYCLES", value: "\(cycleCount)")
                GarageTempoReadoutChip(title: "PHASE", value: phaseLabel)
            }
            .frame(maxWidth: 156)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(GarageProTheme.insetSurface.opacity(isActive ? 0.38 : 0.54), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isActive ? GaragePremiumPalette.gold.opacity(0.16) : GarageProTheme.border, lineWidth: 1)
        )
    }
}

private struct GarageTempoPausedStatus: View {
    let configuration: GarageTempoConfiguration
    let phaseLabel: String
    let cycleCount: Int

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                GarageTempoTrayLabel("Paused")

                Text("Reset. Adjust. Resume.")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                GarageTempoMicroReadout(title: "BPM", value: configuration.bpmText)
                GarageTempoMicroReadout(title: "CYCLES", value: "\(cycleCount)")
                GarageTempoMicroReadout(title: "PHASE", value: phaseLabel)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(GarageProTheme.insetSurface.opacity(0.46), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct GarageTempoMicroReadout: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(title)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(GarageProTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 54, height: 34)
        .background(GarageProTheme.insetSurface.opacity(0.62), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(GarageProTheme.border.opacity(0.64), lineWidth: 1)
        )
    }
}

private struct GarageTempoCockpitBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.004, green: 0.018, blue: 0.014)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.018, green: 0.068, blue: 0.046),
                    Color(red: 0.006, green: 0.024, blue: 0.018),
                    ModuleTheme.garageSurfaceDark.opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    GarageProTheme.accent.opacity(0.22),
                    GaragePremiumPalette.emerald.opacity(0.12),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }
}

private struct GarageTempoTopBar: View {
    let profile: GarageTempoProfile
    let hapticsEnabled: Bool
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button {
                if hapticsEnabled {
                    garageTriggerSelection()
                }
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(GarageProTheme.insetSurface.opacity(0.74), in: Circle())
                    .overlay(Circle().stroke(GarageProTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            Text("Tempo Builder")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            Spacer()

            Text(profile.title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(GaragePremiumPalette.gold)
                .padding(.trailing, 12)
                .frame(width: 94, height: 30, alignment: .trailing)
                .background(GaragePremiumPalette.gold.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(GaragePremiumPalette.gold.opacity(0.18), lineWidth: 1))
        }
    }
}

private struct GarageTempoHeroReadout: View {
    let configuration: GarageTempoConfiguration
    let runState: GarageTempoRunState
    let phaseLabel: String
    let cycleCount: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(configuration.bpmText)
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("BPM")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .padding(.bottom, 12)
            }

            HStack(spacing: 10) {
                GarageTempoReadoutChip(title: "Ratio", value: configuration.ratioText)
                GarageTempoReadoutChip(title: "Cycles", value: "\(cycleCount)")
                GarageTempoReadoutChip(title: "Phase", value: runState == .ready ? "Ready" : phaseLabel)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct GarageTempoReadoutChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(GarageProTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 32)
        .background(GarageProTheme.insetSurface.opacity(0.42), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(GarageProTheme.border.opacity(0.72), lineWidth: 1)
        )
    }
}

private struct GarageTempoDialCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let configuration: GarageTempoConfiguration
    let progress: Double
    let loopPhase: GarageTempoLoopPhase
    let phaseLabel: String
    let runState: GarageTempoRunState
    let cycleCount: Int
    let impactPulseID: Int

    @State private var impactPulse = false

    var body: some View {
        GarageTempoJArcInstrument(
            bpmText: configuration.bpmText,
            progress: progress,
            loopPhase: loopPhase,
            isRunning: runState == .running,
            reduceMotion: reduceMotion,
            impactPulse: impactPulse && reduceMotion == false
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tempo J arc")
        .accessibilityValue("\(phaseLabel), \(configuration.ratioText) ratio, \(cycleCount) cycles")
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(runState == .running ? 0.58 : 0.34)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(runState == .running ? GaragePremiumPalette.gold.opacity(0.22) : GarageProTheme.border, lineWidth: 1)
        )
        .shadow(color: GaragePremiumPalette.gold.opacity(runState == .running ? 0.18 : 0.08), radius: 28, x: 0, y: 18)
        .shadow(color: GarageProTheme.glow.opacity(runState == .running ? 0.18 : 0.10), radius: 18, x: 0, y: 0)
        .onChange(of: impactPulseID) { _, newValue in
            guard newValue > 0 else { return }
            impactPulse = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                impactPulse = false
            }
        }
    }
}

private struct GarageTempoJArcInstrument: View {
    let bpmText: String
    let progress: Double
    let loopPhase: GarageTempoLoopPhase
    let isRunning: Bool
    let reduceMotion: Bool
    let impactPulse: Bool

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var pathProgress: CGFloat {
        switch loopPhase {
        case .setupWait, .reset:
            return 0
        case .backswing:
            let backswingProgress = min(max(clampedProgress / 0.75, 0), 1)
            return CGFloat(pow(backswingProgress, 2.5))
        case .downswing:
            let downswingProgress = min(max((clampedProgress - 0.75) / 0.25, 0), 1)
            return CGFloat(1 - pow(downswingProgress, 0.55))
        }
    }

    private var displayedPathProgress: CGFloat {
        guard reduceMotion else { return pathProgress }

        switch loopPhase {
        case .setupWait, .reset:
            return 0
        case .backswing:
            return 1
        case .downswing:
            return 0
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let rect = proxy.frame(in: .local).insetBy(dx: proxy.size.width * 0.13, dy: proxy.size.height * 0.13)
            let swingPath = jArcPath(in: rect)
            let activePath = progressPath(to: displayedPathProgress, in: rect)
            let addressPoint = point(at: 0, in: rect)
            let topPoint = point(at: 1, in: rect)
            let dotPoint = point(at: displayedPathProgress, in: rect)

            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                GarageProTheme.accent.opacity(0.22),
                                GaragePremiumPalette.emerald.opacity(0.18),
                                GarageProTheme.insetSurface.opacity(0.92)
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: min(proxy.size.width, proxy.size.height) * 0.82
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(GaragePremiumPalette.mintText.opacity(0.07), lineWidth: 1)
                    )
                    .padding(3)
                    .shadow(color: GarageProTheme.glow.opacity(0.18), radius: 28, x: 0, y: 18)

                swingPath
                    .stroke(Color.black.opacity(0.34), style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round))
                    .blur(radius: 1.1)
                    .offset(y: 1.4)

                swingPath
                    .stroke(
                        LinearGradient(
                            colors: [
                                GarageProTheme.textPrimary.opacity(0.18),
                                GaragePremiumPalette.mintText.opacity(0.12)
                            ],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round)
                    )

                swingPath
                    .stroke(
                        LinearGradient(
                            colors: [
                                GarageProTheme.textPrimary.opacity(0.09),
                                GaragePremiumPalette.mintText.opacity(0.06)
                            ],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        ),
                        style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round)
                    )

                activePath
                    .stroke(
                        LinearGradient(
                            colors: [
                                GaragePremiumPalette.gold.opacity(isRunning ? 0.95 : 0.64),
                                GarageProTheme.accent.opacity(isRunning ? 0.92 : 0.48)
                            ],
                            startPoint: .bottom,
                            endPoint: .topTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: GaragePremiumPalette.gold.opacity(isRunning ? 0.34 : 0.16), radius: 14, x: 0, y: 0)

                activePath
                    .stroke(
                        LinearGradient(
                            colors: [
                                GaragePremiumPalette.gold.opacity(isRunning ? 0.54 : 0.20),
                                GaragePremiumPalette.gold.opacity(0.12)
                            ],
                            startPoint: .bottomLeading,
                            endPoint: .top
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 6)
                    .blendMode(.screen)
                    .opacity(isRunning ? 0.86 : 0.52)

                GarageTempoJArcMarker(point: addressPoint, title: "Address", role: .address, labelOffset: CGSize(width: -8, height: 34))
                GarageTempoJArcMarker(point: topPoint, title: "Top", role: .top, labelOffset: CGSize(width: -24, height: -34))
                GarageTempoJArcMarker(point: addressPoint, title: "Impact", role: .impact, isPulsing: impactPulse, labelOffset: CGSize(width: 62, height: 4))

                GarageTempoImpactGate(
                    point: addressPoint,
                    isRunning: isRunning,
                    isPulsing: impactPulse
                )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                GarageProTheme.textPrimary,
                                GaragePremiumPalette.mintText.opacity(0.80)
                            ],
                            center: .center,
                            startRadius: 1,
                            endRadius: 14
                        )
                    )
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        GaragePremiumPalette.gold.opacity(0.96),
                                        GarageProTheme.accent.opacity(0.82)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 5
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(GarageProTheme.textPrimary.opacity(isRunning ? 0.64 : 0.38), lineWidth: 1.5)
                            .padding(2.5)
                    )
                    .shadow(color: GaragePremiumPalette.gold.opacity(isRunning ? 0.46 : 0.22), radius: 12, x: 0, y: 0)
                    .shadow(color: GarageProTheme.glow.opacity(isRunning ? 0.34 : 0.18), radius: 8, x: 0, y: 0)
                    .scaleEffect(impactPulse ? 1.09 : 1)
                    .position(dotPoint)
                    .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.78), value: impactPulse)
                    .animation(reduceMotion ? nil : .linear(duration: 1.0 / 30.0), value: displayedPathProgress)

                VStack(spacing: 1) {
                    Text(bpmText)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(GarageProTheme.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("BPM")
                        .font(.system(size: 6, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(GaragePremiumPalette.gold.opacity(0.84))
                }
                .frame(width: 54, height: 40)
                .background(GarageProTheme.insetSurface.opacity(0.50), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GaragePremiumPalette.gold.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 8, x: 0, y: 4)
                .position(x: rect.minX + 34, y: rect.minY + 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func jArcPath(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addCurve(
                to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.15),
                control1: CGPoint(x: rect.minX - rect.width * 0.10, y: rect.maxY),
                control2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.40)
            )
        }
    }

    private func progressPath(to progress: CGFloat, in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        return jArcPath(in: rect).trimmedPath(from: 0, to: clamped)
    }

    private func point(at progress: CGFloat, in rect: CGRect) -> CGPoint {
        let clamped = min(max(progress, 0), 1)
        return cubicPoint(
            t: clamped,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.minX - rect.width * 0.10, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.40),
            end: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.15)
        )
    }

    private func cubicPoint(t: CGFloat, start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) -> CGPoint {
        let inverse = 1 - t
        let x = pow(inverse, 3) * start.x
            + 3 * pow(inverse, 2) * t * control1.x
            + 3 * inverse * pow(t, 2) * control2.x
            + pow(t, 3) * end.x
        let y = pow(inverse, 3) * start.y
            + 3 * pow(inverse, 2) * t * control1.y
            + 3 * inverse * pow(t, 2) * control2.y
            + pow(t, 3) * end.y
        return CGPoint(x: x, y: y)
    }
}

private struct GarageTempoImpactGate: View {
    let point: CGPoint
    let isRunning: Bool
    let isPulsing: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(GaragePremiumPalette.gold.opacity(isRunning ? 0.36 : 0.22), lineWidth: 7)
                .frame(width: 70, height: 70)
                .blur(radius: 0.8)

            Circle()
                .stroke(GarageProTheme.accent.opacity(isPulsing ? 0.84 : 0.54), lineWidth: isPulsing ? 3.4 : 2.6)
                .frame(width: isPulsing ? 78 : 68, height: isPulsing ? 78 : 68)
                .shadow(color: GarageProTheme.accent.opacity(isPulsing ? 0.52 : 0.24), radius: isPulsing ? 14 : 8, x: 0, y: 0)
                .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isPulsing)

            Circle()
                .stroke(GaragePremiumPalette.gold.opacity(0.28), lineWidth: 1)
                .frame(width: 54, height: 54)
        }
        .position(point)
    }
}

private struct GarageTempoJArcMarker: View {
    let point: CGPoint
    let title: String
    var role: GarageTempoMarkerRole = .address
    var isPulsing = false
    var labelOffset = CGSize(width: 0, height: 22)

    var body: some View {
        ZStack {
            Circle()
                .stroke(role.color.opacity(isPulsing ? 0.58 : (role == .address ? 0.20 : 0.30)), lineWidth: role == .impact ? 3 : 1.6)
                .frame(
                    width: isPulsing ? role.haloSize + 18 : role.haloSize,
                    height: isPulsing ? role.haloSize + 18 : role.haloSize
                )
                .shadow(color: role.color.opacity(role == .impact ? 0.32 : 0.16), radius: role == .impact ? 10 : 6, x: 0, y: 0)
                .animation(.spring(response: 0.24, dampingFraction: 0.68), value: isPulsing)

            Circle()
                .fill(role.color)
                .frame(width: role.markerSize, height: role.markerSize)
        }
        .overlay {
            Text(title)
                .font(.system(size: role == .impact ? 11 : 10, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(role == .top ? 1.25 : 1.45)
                .foregroundStyle(role == .impact ? GarageProTheme.accent.opacity(role.labelOpacity) : GarageProTheme.textPrimary.opacity(role.labelOpacity))
                .fixedSize()
                .offset(labelOffset)
                .shadow(color: role.color.opacity(role == .impact ? 0.28 : 0.14), radius: 5, x: 0, y: 0)
        }
        .position(point)
    }
}

private struct GarageTempoLandmarkGate: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let span: Double

    var body: some View {
        Circle()
            .trim(from: max(progress - span / 2, 0), to: min(progress + span / 2, 1))
            .stroke(
                color.opacity(0.84),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .shadow(color: color.opacity(0.32), radius: 8, x: 0, y: 0)
    }
}

private enum GarageTempoMarkerRole: Equatable {
    case address
    case top
    case impact

    var color: Color {
        switch self {
        case .address:
            return GaragePremiumPalette.gold
        case .top:
            return GaragePremiumPalette.gold.opacity(0.82)
        case .impact:
            return GarageProTheme.accent
        }
    }

    var markerSize: CGFloat {
        switch self {
        case .address:
            return 11
        case .top:
            return 15
        case .impact:
            return 23
        }
    }

    var haloSize: CGFloat {
        switch self {
        case .address:
            return 24
        case .top:
            return 32
        case .impact:
            return 54
        }
    }

    var labelOpacity: Double {
        switch self {
        case .address:
            return 0.88
        case .top:
            return 0.80
        case .impact:
            return 0.96
        }
    }
}

private struct GarageTempoMarker: View {
    let point: CGPoint
    let title: String
    var role: GarageTempoMarkerRole = .address
    var isPulsing = false
    var labelOffset = CGSize(width: 0, height: 22)

    var body: some View {
        ZStack {
            Circle()
                .stroke(role.color.opacity(isPulsing ? 0.58 : (role == .address ? 0.18 : 0.28)), lineWidth: role == .impact ? 3 : 1.6)
                .frame(
                    width: isPulsing ? role.haloSize + 20 : role.haloSize,
                    height: isPulsing ? role.haloSize + 20 : role.haloSize
                )
                .shadow(color: role.color.opacity(role == .impact ? 0.34 : 0.18), radius: role == .impact ? 10 : 6, x: 0, y: 0)
                .animation(.spring(response: 0.24, dampingFraction: 0.68), value: isPulsing)

            Circle()
                .fill(role.color)
                .frame(width: role.markerSize, height: role.markerSize)
        }
        .overlay(alignment: .bottom) {
                Text(title)
                    .font(.system(size: role == .impact ? 11 : 10, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(role == .top ? 1.25 : 1.45)
                    .foregroundStyle(role == .impact ? GarageProTheme.accent.opacity(role.labelOpacity) : GarageProTheme.textPrimary.opacity(role.labelOpacity))
                    .fixedSize()
                    .offset(labelOffset)
                    .shadow(color: role.color.opacity(role == .impact ? 0.28 : 0.14), radius: 5, x: 0, y: 0)
        }
        .position(point)
    }
}

private struct GarageTempoSetupPanel: View {
    @Binding var configuration: GarageTempoConfiguration
    @Binding var profile: GarageTempoProfile
    let hapticsEnabled: Bool
    let onConfigurationChange: (GarageTempoConfiguration) -> Void

    var body: some View {
        VStack(spacing: 7) {
            GarageTempoSliderControlCard(
                title: "BPM",
                valueText: configuration.bpmText,
                value: Binding(
                    get: { configuration.beatsPerMinute },
                    set: { nextValue in
                        configuration.beatsPerMinute = nextValue.rounded()
                        onConfigurationChange(configuration)
                    }
                ),
                bounds: 60...90,
                step: 1
            )

            GarageTempoSliderControlCard(
                title: "Setup",
                valueText: configuration.setupDelayText,
                value: Binding(
                    get: { configuration.setupDelay },
                    set: { nextValue in
                        configuration.setupDelay = nextValue.rounded()
                        onConfigurationChange(configuration)
                    }
                ),
                bounds: 3...10,
                step: 1
            )

            GarageTempoProfileUtilityCard(
                profile: $profile,
                configuration: $configuration,
                hapticsEnabled: hapticsEnabled,
                onConfigurationChange: onConfigurationChange
            )
        }
    }
}

private struct GarageTempoLiveTuneDock: View {
    @Binding var configuration: GarageTempoConfiguration
    @Binding var profile: GarageTempoProfile
    let hapticsEnabled: Bool
    let onConfigurationChange: (GarageTempoConfiguration) -> Void

    var body: some View {
        HStack(spacing: 7) {
            GarageTempoCompactSliderCard(
                title: "BPM",
                value: configuration.bpmText,
                sliderValue: Binding(
                    get: { configuration.beatsPerMinute },
                    set: { nextValue in
                        configuration.beatsPerMinute = nextValue.rounded()
                        onConfigurationChange(configuration)
                    }
                ),
                bounds: 60...90,
                step: 1
            )

            GarageTempoCompactSliderCard(
                title: "Setup",
                value: configuration.setupDelayText,
                sliderValue: Binding(
                    get: { configuration.setupDelay },
                    set: { nextValue in
                        configuration.setupDelay = nextValue.rounded()
                        onConfigurationChange(configuration)
                    }
                ),
                bounds: 3...10,
                step: 1
            )

            GarageTempoProfileDockCard(
                profile: $profile,
                configuration: $configuration,
                hapticsEnabled: hapticsEnabled,
                onConfigurationChange: onConfigurationChange
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(GarageProTheme.insetSurface.opacity(0.42), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.13), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Live tune dock")
    }
}

private struct GarageTempoSliderControlCard: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let bounds: ClosedRange<Double>
    let step: Double

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)

                Text(valueText)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 82, alignment: .leading)

            Slider(value: $value, in: bounds, step: step)
                .tint(GaragePremiumPalette.gold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(GarageProTheme.insetSurface.opacity(0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct GarageTempoCompactSliderCard: View {
    let title: String
    let value: String
    @Binding var sliderValue: Double
    let bounds: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(GarageProTheme.textSecondary)

                Spacer(minLength: 2)

                Text(value)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }

            Slider(value: $sliderValue, in: bounds, step: step)
                .tint(GaragePremiumPalette.gold)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(GarageProTheme.insetSurface.opacity(0.54), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.13), lineWidth: 1)
        )
    }
}

private struct GarageTempoProfileUtilityCard: View {
    @Binding var profile: GarageTempoProfile
    @Binding var configuration: GarageTempoConfiguration
    let hapticsEnabled: Bool
    let onConfigurationChange: (GarageTempoConfiguration) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profile")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)

                Text(profile.title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 8)

            GarageTempoIconButton(systemImage: "chevron.left", size: 34, hapticsEnabled: hapticsEnabled, action: selectPreviousProfile)
            GarageTempoIconButton(systemImage: "chevron.right", size: 34, hapticsEnabled: hapticsEnabled, action: selectNextProfile)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(GarageProTheme.insetSurface.opacity(0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.10), lineWidth: 1)
        )
    }

    private func selectPreviousProfile() {
        selectProfile(offset: -1)
    }

    private func selectNextProfile() {
        selectProfile(offset: 1)
    }

    private func selectProfile(offset: Int) {
        let profiles = GarageTempoProfile.allCases
        guard let currentIndex = profiles.firstIndex(of: profile) else { return }
        let nextIndex = (currentIndex + offset + profiles.count) % profiles.count
        profile = profiles[nextIndex]
        let defaults = profile.tempoDefaults
        configuration.beatsPerMinute = defaults.beatsPerMinute
        configuration.setupDelay = defaults.setupDelay
        onConfigurationChange(configuration)
    }
}

private struct GarageTempoProfileDockCard: View {
    @Binding var profile: GarageTempoProfile
    @Binding var configuration: GarageTempoConfiguration
    let hapticsEnabled: Bool
    let onConfigurationChange: (GarageTempoConfiguration) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Profile")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(GarageProTheme.textSecondary)

            HStack(spacing: 3) {
                GarageTempoIconButton(systemImage: "chevron.left", size: 25, hapticsEnabled: hapticsEnabled, action: selectPreviousProfile)

                Text(profile.title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.52)
                    .frame(maxWidth: .infinity)

                GarageTempoIconButton(systemImage: "chevron.right", size: 25, hapticsEnabled: hapticsEnabled, action: selectNextProfile)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(GarageProTheme.insetSurface.opacity(0.54), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GaragePremiumPalette.gold.opacity(0.13), lineWidth: 1)
        )
    }

    private func selectPreviousProfile() {
        selectProfile(offset: -1)
    }

    private func selectNextProfile() {
        selectProfile(offset: 1)
    }

    private func selectProfile(offset: Int) {
        let profiles = GarageTempoProfile.allCases
        guard let currentIndex = profiles.firstIndex(of: profile) else { return }
        let nextIndex = (currentIndex + offset + profiles.count) % profiles.count
        profile = profiles[nextIndex]
        let defaults = profile.tempoDefaults
        configuration.beatsPerMinute = defaults.beatsPerMinute
        configuration.setupDelay = defaults.setupDelay
        onConfigurationChange(configuration)
    }
}

private struct GarageTempoActionBar: View {
    let primaryTitle: String
    let primaryIcon: String
    let isPrimaryActive: Bool
    var stopTitle = "Stop"
    var moreTitle = "More"
    var showsStop = true
    var showsMore = true
    var canStop = true
    let hapticsEnabled: Bool
    let onPrimaryAction: () -> Void
    let onStop: () -> Void
    let onMore: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            Button {
                if hapticsEnabled {
                    garageTriggerSelection()
                }
                onPrimaryAction()
            } label: {
                Label(primaryTitle, systemImage: primaryIcon)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(ModuleTheme.garageSurfaceDark)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(
                        LinearGradient(
                            colors: [
                                GaragePremiumPalette.gold,
                                GaragePremiumPalette.gold.opacity(isPrimaryActive ? 0.76 : 0.62),
                                GarageProTheme.accent.opacity(0.54)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
                    .shadow(color: GaragePremiumPalette.gold.opacity(isPrimaryActive ? 0.24 : 0.12), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Spacer(minLength: 0)

                if showsStop {
                    GarageTempoAuxiliaryButton(
                        title: stopTitle,
                        systemImage: "stop.fill",
                        isEnabled: canStop,
                        hapticsEnabled: hapticsEnabled,
                        action: onStop
                    )
                }

                if showsMore {
                    GarageTempoAuxiliaryButton(
                        title: moreTitle,
                        systemImage: "ellipsis",
                        isEnabled: true,
                        hapticsEnabled: hapticsEnabled,
                        action: onMore
                    )
                }
            }
        }
    }
}

private struct GarageTempoAuxiliaryButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let hapticsEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            if hapticsEnabled {
                garageTriggerSelection()
            }
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .black))

                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .foregroundStyle(GarageProTheme.textPrimary.opacity(isEnabled ? 0.92 : 0.42))
            .frame(minWidth: 76, minHeight: 32)
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .background(GarageProTheme.insetSurface.opacity(0.46), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(GarageProTheme.border.opacity(0.72), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
    }
}

private struct GarageTempoTrayLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .textCase(.uppercase)
            .tracking(2)
            .foregroundStyle(GaragePremiumPalette.gold.opacity(0.86))
    }
}

private struct GarageTempoChip: View {
    let title: String
    let isSelected: Bool
    var hapticsEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            guard isSelected == false else { return }
            if hapticsEnabled {
                garageTriggerSelection()
            }
            action()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(isSelected ? GarageProTheme.textPrimary : GarageProTheme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(isSelected ? GarageProTheme.accent.opacity(0.18) : GarageProTheme.insetSurface.opacity(0.72), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? GarageProTheme.accent.opacity(0.42) : GarageProTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct GarageTempoIconButton: View {
    let systemImage: String
    var size: CGFloat = 36
    var isEnabled = true
    var hapticsEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            if hapticsEnabled {
                garageTriggerSelection()
            }
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(GarageProTheme.textPrimary)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(GarageProTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false)
    }
}

private struct GarageTempoMoreControlsSheet: View {
    @Binding var configuration: GarageTempoConfiguration
    @Binding var profile: GarageTempoProfile

    let engineState: GarageTempoRunState
    let onConfigurationChange: (GarageTempoConfiguration) -> Void
    let onReset: () -> Void
    let onPulse: () -> Void

    var body: some View {
        ZStack {
            GarageTempoCockpitBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GarageProSectionHeader(eyebrow: "More", title: "Cue Setup")

                    GarageProCard(cornerRadius: 22, padding: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            GarageTempoTrayLabel("Profile")

                            HStack(spacing: 8) {
                                ForEach(GarageTempoProfile.allCases) { option in
                                    GarageTempoChip(
                                        title: option.title,
                                        isSelected: profile == option,
                                        hapticsEnabled: configuration.hapticsEnabled
                                    ) {
                                        profile = option
                                        let defaults = option.tempoDefaults
                                        configuration.beatsPerMinute = defaults.beatsPerMinute
                                        configuration.setupDelay = defaults.setupDelay
                                        onConfigurationChange(configuration)
                                    }
                                }
                            }
                        }
                    }

                    GarageProCard(cornerRadius: 22, padding: 14) {
                        Toggle("Audio cues", isOn: Binding(
                            get: { configuration.audioEnabled },
                            set: { isEnabled in
                                configuration.audioEnabled = isEnabled
                                configuration.hapticsEnabled = false
                                onConfigurationChange(configuration)
                            }
                        ))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(GarageProTheme.textPrimary)

                        Text("AirPods-first harmonic sine tones. Haptics stay off for clean tempo feedback.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(GarageProTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    GarageProCard(cornerRadius: 22, padding: 14) {
                        GarageTempoSliderRow(
                            title: "Advanced BPM",
                            valueText: configuration.bpmText,
                            rangeText: "Fine pace control",
                            value: Binding(
                                get: { configuration.beatsPerMinute },
                                set: { nextValue in
                                    configuration.beatsPerMinute = nextValue.rounded()
                                    onConfigurationChange(configuration)
                                }
                            ),
                            bounds: 60...90,
                            step: 1
                        )

                        GarageTempoSliderRow(
                            title: "Setup Wait",
                            valueText: configuration.setupDelayText,
                            rangeText: "Silent address reset",
                            value: Binding(
                                get: { configuration.setupDelay },
                                set: { nextValue in
                                    configuration.setupDelay = nextValue.rounded()
                                    onConfigurationChange(configuration)
                                }
                            ),
                            bounds: 3...10,
                            step: 1
                        )
                    }

                    HStack(spacing: 10) {
                        GarageTempoSecondaryButton(
                            title: "Test cue",
                            systemImage: "checkmark.seal.fill",
                            isEnabled: true,
                            hapticsEnabled: configuration.hapticsEnabled,
                            action: onPulse
                        )

                        GarageTempoSecondaryButton(
                            title: "Reset",
                            systemImage: "arrow.counterclockwise",
                            isEnabled: engineState != .ready,
                            hapticsEnabled: configuration.hapticsEnabled,
                            action: onReset
                        )
                    }

                    GarageTempoFoundationCard(configuration: configuration)
                }
                .padding(18)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct GarageTempoSliderRow: View {
    let title: String
    let valueText: String
    let rangeText: String
    @Binding var value: Double
    let bounds: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text(rangeText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GarageProTheme.textSecondary)
                }

                Spacer(minLength: 12)

                Text(valueText)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(GaragePremiumPalette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Slider(value: $value, in: bounds, step: step)
                .tint(GarageProTheme.accent)
        }
        .padding(14)
        .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GarageProTheme.border, lineWidth: 1)
        )
    }
}

private struct GarageTempoSecondaryButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    var isProminent = false
    var hapticsEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            if hapticsEnabled {
                garageTriggerSelection()
            }
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(isProminent ? ModuleTheme.garageSurfaceDark : GarageProTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(GarageProTheme.insetSurface.opacity(0.9))

                    if isProminent {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        GaragePremiumPalette.gold,
                                        GarageProTheme.accent.opacity(0.82)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isProminent ? Color.white.opacity(0.22) : GarageProTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.44)
        .disabled(isEnabled == false)
    }
}

private struct GarageTempoFoundationCard: View {
    let configuration: GarageTempoConfiguration

    var body: some View {
        GarageProCard(cornerRadius: 24, padding: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GarageProTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(GarageProTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Local rehearsal tool")
                        .font(.headline.weight(.black))
                        .foregroundStyle(GarageProTheme.textPrimary)

                    Text("No camera, mic, AI, or sensor-based claims. History and saved fingerprints stay behind a later persistence gate.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GarageProTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(configuration.bpmText) BPM - \(configuration.setupDelayText) setup - \(configuration.ratioText) tempo")
                        .font(.caption.weight(.black))
                        .foregroundStyle(GaragePremiumPalette.gold)
                }
            }
        }
    }
}
