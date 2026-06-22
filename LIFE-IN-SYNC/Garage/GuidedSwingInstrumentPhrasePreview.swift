#if DEBUG
import AVFoundation
import Combine
import SwiftUI

enum GuidedSwingInstrumentPhraseCandidate: String, CaseIterable, Identifiable {
    case mutedRhodes
    case feltPiano
    case rosewoodMarimba
    case nylonGuitar
    case luxuryUIChime
    case humanRhythm

    struct Event: Sendable {
        let assetName: String
        let offset: TimeInterval
    }

    enum SourcingPriority: String, Sendable {
        case primary = "Primary"
        case secondary = "Secondary"
        case exploratory = "Exploratory"
        case specOnly = "Spec Only"
    }

    static let eventOffsets: [TimeInterval] = [0.00, 0.58, 1.16, 1.90]
    static let backswingEnd: TimeInterval = 1.74
    static let silentTopPause: TimeInterval = 0.16

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mutedRhodes: "Muted Rhodes Phrase"
        case .feltPiano: "Felt Piano Phrase"
        case .rosewoodMarimba: "Soft Rosewood Marimba Phrase"
        case .nylonGuitar: "Muted Nylon Guitar Phrase"
        case .luxuryUIChime: "Luxury UI Chime Phrase"
        case .humanRhythm: "Human Rhythm Phrase Spec"
        }
    }

    var listeningNote: String {
        switch self {
        case .mutedRhodes: "Warm A3, C4, D4 rise; muted A3/D4 confirmation. Preferred first listen."
        case .feltPiano: "Dry, restrained ascending notes with a soft low/mid confirmation."
        case .rosewoodMarimba: "Rounded rosewood attacks; athletic, warm, and never toy-like."
        case .nylonGuitar: "Short human plucks with a muted double-stop confirmation."
        case .luxuryUIChime: "Three damped tonal events with one quiet premium confirmation."
        case .humanRhythm: "Spec only: restrained coach cadence such as “one… two… three… go.”"
        }
    }

    var rank: Int {
        switch self {
        case .mutedRhodes: 1
        case .feltPiano: 2
        case .rosewoodMarimba: 3
        case .nylonGuitar: 4
        case .luxuryUIChime: 5
        case .humanRhythm: 6
        }
    }

    var sourcingPriority: SourcingPriority {
        switch self {
        case .mutedRhodes: .primary
        case .feltPiano, .rosewoodMarimba: .secondary
        case .nylonGuitar, .luxuryUIChime: .exploratory
        case .humanRhythm: .specOnly
        }
    }

    var musicalMap: String {
        switch self {
        case .mutedRhodes: "A3 → C4 → D4 → silence → A3/D4"
        case .feltPiano: "G3 → B3 → D4 → silence → G3/D4"
        case .rosewoodMarimba: "A3 → C4 → E4 → silence → A3"
        case .nylonGuitar: "E3 → G3 → B3 → silence → E3/B3"
        case .luxuryUIChime: "C4 → E4 → G4 → silence → C4"
        case .humanRhythm: "Cadence coaching only; no initial voice playback"
        }
    }

    var registerGuidance: String {
        switch self {
        case .mutedRhodes: "A3–D4; avoid climbing above E4"
        case .feltPiano: "G3–D4; keep the body dry and low-mid"
        case .rosewoodMarimba: "A3–E4 only with a rounded, warm sample"
        case .nylonGuitar: "E3–B3; preserve a calm human attack"
        case .luxuryUIChime: "C4–G4 only when dark and damped"
        case .humanRhythm: "Restrained golf-coach delivery"
        }
    }

    var decayGuidance: String {
        switch self {
        case .mutedRhodes: "260–420ms notes · 180–300ms confirmation"
        case .feltPiano: "220–360ms notes · damped low-mid confirmation"
        case .rosewoodMarimba: "180–280ms notes · short warm confirmation"
        case .nylonGuitar: "180–320ms notes · muted pluck confirmation"
        case .luxuryUIChime: "120–220ms events · damped confirmation"
        case .humanRhythm: "Not applicable until a later training mode"
        }
    }

    var impactGuidance: String {
        switch self {
        case .mutedRhodes: "Soft muted dyad or restrained lower-note resolution."
        case .feltPiano: "Damped G3/D4 resolution without cinematic bass weight."
        case .rosewoodMarimba: "Short warm A3 mallet resolution without a bonk."
        case .nylonGuitar: "Muted E3/B3 double-stop, never a strum."
        case .luxuryUIChime: "Soft lower C4 confirmation, never a ping."
        case .humanRhythm: "The final syllable should coach release, not imitate impact."
        }
    }

    var rejectionGuidance: String {
        switch self {
        case .mutedRhodes: "Reject lounge cheese, cheap keyboard tone, chorus, reverb, or pad character."
        case .feltPiano: "Reject trailer piano, bright plink, music box, or prestige-drama sadness."
        case .rosewoodMarimba: "Reject toy xylophone, playful bounce, or wooden clack."
        case .nylonGuitar: "Reject spa drift, campfire mood, sleepy pacing, or finger squeak."
        case .luxuryUIChime: "Reject notification, alarm, medical-device, or piercing overtones."
        case .humanRhythm: "Reject motivational, theatrical, synthetic, or gimmicky delivery."
        }
    }

    var requiredAssetNames: [String] {
        switch self {
        case .mutedRhodes:
            ["muted_rhodes_01_A3", "muted_rhodes_02_C4", "muted_rhodes_03_D4", "muted_rhodes_impact_A3_D4"]
        case .feltPiano:
            ["felt_piano_01_G3", "felt_piano_02_B3", "felt_piano_03_D4", "felt_piano_impact_G3_D4"]
        case .rosewoodMarimba:
            ["rosewood_marimba_01_A3", "rosewood_marimba_02_C4", "rosewood_marimba_03_E4", "rosewood_marimba_impact_A3"]
        case .nylonGuitar:
            ["nylon_guitar_01_E3", "nylon_guitar_02_G3", "nylon_guitar_03_B3", "nylon_guitar_impact_E3_B3"]
        case .luxuryUIChime:
            ["luxury_ui_chime_01_C4", "luxury_ui_chime_02_E4", "luxury_ui_chime_03_G4", "luxury_ui_chime_impact_C4"]
        case .humanRhythm:
            []
        }
    }

    var events: [Event] {
        guard requiredAssetNames.isEmpty == false else { return [] }

        return zip(requiredAssetNames, Self.eventOffsets).map { assetName, offset in
            Event(assetName: assetName, offset: offset)
        }
    }

    var timingSummary: String {
        self == .humanRhythm ? "Spec only · no voice asset" : "1.74s rise · 160ms silence · compact confirmation"
    }

    var isSpecOnly: Bool { self == .humanRhythm }
}

@MainActor
final class GuidedSwingInstrumentPhrasePreviewPlayer: ObservableObject {
    @Published private(set) var activeCandidate: GuidedSwingInstrumentPhraseCandidate?
    @Published private(set) var statusText = "Choose an available phrase"

    private var players: [AVAudioPlayer] = []
    private var previewTask: Task<Void, Never>?

    func isAvailable(_ candidate: GuidedSwingInstrumentPhraseCandidate) -> Bool {
        candidate.events.isEmpty == false && candidate.events.allSatisfy { assetURL(named: $0.assetName) != nil }
    }

    func missingAssetCount(for candidate: GuidedSwingInstrumentPhraseCandidate) -> Int {
        candidate.events.filter { assetURL(named: $0.assetName) == nil }.count
    }

    func toggle(_ candidate: GuidedSwingInstrumentPhraseCandidate) {
        if activeCandidate == candidate {
            stop()
        } else {
            play(candidate)
        }
    }

    func stop() {
        previewTask?.cancel()
        previewTask = nil
        players.forEach { $0.stop() }
        players.removeAll()
        activeCandidate = nil
        statusText = "Preview stopped"
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func play(_ candidate: GuidedSwingInstrumentPhraseCandidate) {
        stop()
        guard isAvailable(candidate) else {
            statusText = candidate.isSpecOnly ? "Human rhythm remains spec-only" : "Licensed samples are not bundled"
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            statusText = "Audio session unavailable"
            return
        }

        activeCandidate = candidate
        statusText = "Playing \(candidate.title)"
        previewTask = Task { [weak self] in
            var previousOffset: TimeInterval = 0

            for event in candidate.events {
                let delay = max(event.offset - previousOffset, 0)
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                guard Task.isCancelled == false, let self else { return }
                self.playEvent(named: event.assetName)
                previousOffset = event.offset
            }

            try? await Task.sleep(nanoseconds: 700_000_000)
            guard Task.isCancelled == false, let self else { return }
            self.stopAfterCompletion()
        }
    }

    private func playEvent(named assetName: String) {
        guard let url = assetURL(named: assetName), let player = try? AVAudioPlayer(contentsOf: url) else {
            stop()
            statusText = "Could not decode \(assetName).wav"
            return
        }

        player.volume = 0.72
        player.prepareToPlay()
        players.removeAll { $0.isPlaying == false }
        players.append(player)
        player.play()
    }

    private func stopAfterCompletion() {
        players.removeAll()
        previewTask = nil
        activeCandidate = nil
        statusText = "Preview complete"
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func assetURL(named assetName: String) -> URL? {
        Bundle.main.url(forResource: assetName, withExtension: "wav", subdirectory: "GuidedSwingInstrumentPreview_Audio")
            ?? Bundle.main.url(forResource: assetName, withExtension: "wav", subdirectory: "Garage/GuidedSwingInstrumentPreview_Audio")
            ?? Bundle.main.url(forResource: assetName, withExtension: "wav")
    }
}

struct GuidedSwingInstrumentPhrasePreviewView: View {
    @StateObject private var player = GuidedSwingInstrumentPhrasePreviewPlayer()

    var body: some View {
        ZStack {
            GarageProTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    header
                    sourcingNotice
                    coachingIntent
                    listeningProtocol

                    ForEach(GuidedSwingInstrumentPhraseCandidate.allCases) { candidate in
                        candidateRow(candidate)
                    }

                    decisionFramework
                }
                .padding(20)
                .padding(.bottom, 28)
            }
        }
        .onDisappear { player.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Instrument Phrase Preview")
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text("DEBUG-only · isolated from live Guided Swing")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)

            Text(player.statusText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(GaragePremiumPalette.gold)
                .padding(.top, 3)
        }
        .accessibilityElement(children: .combine)
    }

    private var sourcingNotice: some View {
        Text("No approved instrument samples are currently bundled. Preview buttons unlock only when every required WAV has documented, app-safe provenance. There is no synthetic fallback.")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(GarageProTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(GarageProTheme.elevatedSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(GarageProTheme.border, lineWidth: 1))
    }

    private var coachingIntent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MAKE THE GOLFER MOVE CORRECTLY")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(GaragePremiumPalette.gold)

            Text("Load calmly. Wait at the top. Release decisively. Finish resolved.")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text("The target feeling: “I know when to move, I trust the rhythm, and I can repeat this without irritation.”")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(GaragePremiumPalette.gold.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var listeningProtocol: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("10-SWING LISTENING PROTOCOL")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(GaragePremiumPalette.mintText)

            Text("Use the same physical iPhone, volume, and room. Complete exactly 10 fake swings before scoring unless the sound is instantly offensive.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text("Score only: pleasantness · timing clarity · intentional silence · resolved impact · five-minute practice willingness")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(GarageProTheme.elevatedSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(GarageProTheme.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func candidateRow(_ candidate: GuidedSwingInstrumentPhraseCandidate) -> some View {
        let available = player.isAvailable(candidate)
        let isPlaying = player.activeCandidate == candidate

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(candidate.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Spacer(minLength: 8)

                Text("#\(candidate.rank) · \(candidate.sourcingPriority.rawValue.uppercased())")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(candidate == .mutedRhodes ? GaragePremiumPalette.gold : GarageProTheme.textSecondary)
            }

            Text(candidate.listeningNote)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)

            Text(candidate.musicalMap)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(GaragePremiumPalette.mintText)

            Text("\(candidate.registerGuidance) · \(candidate.decayGuidance)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)

            Text(candidate.impactGuidance)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)

            Text(candidate.rejectionGuidance)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary.opacity(0.82))

            if available == false, candidate.isSpecOnly == false {
                Text("Missing: \(missingAssetNames(for: candidate).map { "\($0).wav" }.joined(separator: ", "))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(GarageProTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Label(candidate.timingSummary, systemImage: "metronome")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)

                Spacer(minLength: 8)

                Button(isPlaying ? "Stop" : "Preview") {
                    player.toggle(candidate)
                }
                .buttonStyle(GuidedSwingPhrasePreviewButtonStyle(isActive: isPlaying))
                .disabled(available == false)
                .accessibilityHint(available ? "Plays one fixed-timing phrase" : unavailableHint(for: candidate))
            }
        }
        .padding(16)
        .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isPlaying ? GaragePremiumPalette.gold.opacity(0.72) : GarageProTheme.border, lineWidth: 1))
    }

    private func unavailableHint(for candidate: GuidedSwingInstrumentPhraseCandidate) -> String {
        candidate.isSpecOnly
            ? "Voice generation and recording are intentionally excluded"
            : "Requires \(player.missingAssetCount(for: candidate)) documented WAV assets"
    }

    private func missingAssetNames(for candidate: GuidedSwingInstrumentPhraseCandidate) -> [String] {
        candidate.requiredAssetNames.filter { name in
            Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "GuidedSwingInstrumentPreview_Audio") == nil
                && Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Garage/GuidedSwingInstrumentPreview_Audio") == nil
                && Bundle.main.url(forResource: name, withExtension: "wav") == nil
        }
    }

    private var decisionFramework: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("DECISION RULES")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(GaragePremiumPalette.gold)

            Text("Pleasant but unclear → adjust spacing\nClear but annoying → reject timbre\nPremium but too musical → shorten decay and remove reverb\nAthletic but cheap → soften attack and lower register\nNone survive 10 swings → reject the sound family")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textPrimary)
                .lineSpacing(4)

            Text("Immediate rejection: fatigue, toy feeling, lounge music, spa drift, notification vibe, harsh ping, muddy body noise, synthetic hum, or punt-phone energy.")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(GarageProTheme.insetSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(GarageProTheme.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct GuidedSwingPhrasePreviewButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(isActive ? GaragePremiumPalette.emeraldDeep : GarageProTheme.textPrimary)
            .frame(minWidth: 76, minHeight: 44)
            .background(isActive ? GaragePremiumPalette.gold : GarageProTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(GarageProTheme.border, lineWidth: isActive ? 0 : 1))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
#endif
