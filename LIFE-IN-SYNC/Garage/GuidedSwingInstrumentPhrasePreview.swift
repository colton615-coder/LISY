#if DEBUG
import AVFoundation
import Combine
import SwiftUI

enum GuidedSwingAuditionLaneID: String, CaseIterable, Identifiable, Sendable {
    case rejectedPremiumLiftHillBaseline
    case apexLift
    case cableWinch
    case torqueRatchet
    case hydraulicLoad
    case trackLock
    case tourMechanism
    case minimalImpactOnly

    var id: String { rawValue }
}

enum GuidedSwingAuditionSlotRole: String, Sendable {
    case backswingBuild
    case impact

    var title: String {
        switch self {
        case .backswingBuild: "Build"
        case .impact: "Impact"
        }
    }
}

struct GuidedSwingAuditionSlot: Identifiable, Equatable, Sendable {
    let role: GuidedSwingAuditionSlotRole
    let assetName: String
    let offset: TimeInterval
    let isRequired: Bool
    let gain: Double

    var id: String { assetName }
}

struct GuidedSwingAuditionLane: Identifiable, Equatable, Sendable {
    let id: GuidedSwingAuditionLaneID
    let displayName: String
    let intent: String
    let slots: [GuidedSwingAuditionSlot]
    let backswingDuration: TimeInterval
    let apexSilenceDuration: TimeInterval
    let impactTrimDuration: TimeInterval
    let requiresProvenanceManifest: Bool
    let isRejectedBaseline: Bool

    var impactOffset: TimeInterval {
        backswingDuration + apexSilenceDuration
    }

    var requiredSlots: [GuidedSwingAuditionSlot] {
        slots.filter(\.isRequired)
    }

    var expectedAssetNames: [String] {
        slots.map(\.assetName)
    }

    static let auditionManifestName = "GUIDED_SWING_AUDITION_SOURCE_MANIFEST"

    static let all: [Self] = [
        Self(
            id: .rejectedPremiumLiftHillBaseline,
            displayName: "Baseline: Premium Lift Hill",
            intent: "Current rejected live Apex Lift baseline for A/B comparison only.",
            slots: [
                GuidedSwingAuditionSlot(role: .backswingBuild, assetName: "backswing_premium_lift_hill", offset: 0, isRequired: true, gain: 0.72),
                GuidedSwingAuditionSlot(role: .impact, assetName: "impact_golf_swing", offset: 2.00, isRequired: true, gain: 0.72)
            ],
            backswingDuration: 1.50,
            apexSilenceDuration: 0.50,
            impactTrimDuration: 0.32,
            requiresProvenanceManifest: false,
            isRejectedBaseline: true
        ),
        Self(
            id: .apexLift,
            displayName: "Apex Lift",
            intent: "True roller-coaster climb energy with controlled apex silence and compact strike.",
            slots: Self.twoSlotLane("apex_lift"),
            backswingDuration: 1.60,
            apexSilenceDuration: 0.36,
            impactTrimDuration: 0.30,
            requiresProvenanceManifest: true,
            isRejectedBaseline: false
        ),
        Self(
            id: .cableWinch,
            displayName: "Cable Winch",
            intent: "Heavier mechanical pull; athletic training tension without amusement-park character.",
            slots: Self.twoSlotLane("cable_winch"),
            backswingDuration: 1.70,
            apexSilenceDuration: 0.34,
            impactTrimDuration: 0.28,
            requiresProvenanceManifest: true,
            isRejectedBaseline: false
        ),
        Self(
            id: .torqueRatchet,
            displayName: "Torque Ratchet",
            intent: "Dry precision sequencing with restrained notches and no goofy exaggeration.",
            slots: Self.twoSlotLane("torque_ratchet"),
            backswingDuration: 1.55,
            apexSilenceDuration: 0.38,
            impactTrimDuration: 0.26,
            requiresProvenanceManifest: true,
            isRejectedBaseline: false
        ),
        Self(
            id: .hydraulicLoad,
            displayName: "Hydraulic Load",
            intent: "Low-pressure machine weight and compression; less clicky, more physical mass.",
            slots: Self.twoSlotLane("hydraulic_load"),
            backswingDuration: 1.80,
            apexSilenceDuration: 0.32,
            impactTrimDuration: 0.30,
            requiresProvenanceManifest: true,
            isRejectedBaseline: false
        ),
        Self(
            id: .trackLock,
            displayName: "Track Lock",
            intent: "Premium mechanism engaging into controlled positions on the way to the top.",
            slots: Self.twoSlotLane("track_lock"),
            backswingDuration: 1.58,
            apexSilenceDuration: 0.36,
            impactTrimDuration: 0.26,
            requiresProvenanceManifest: true,
            isRejectedBaseline: false
        ),
        Self(
            id: .tourMechanism,
            displayName: "Tour Mechanism",
            intent: "Quiet athletic gear, polished and minimal for a serious golf-training tool.",
            slots: Self.twoSlotLane("tour_mechanism"),
            backswingDuration: 1.62,
            apexSilenceDuration: 0.40,
            impactTrimDuration: 0.24,
            requiresProvenanceManifest: true,
            isRejectedBaseline: false
        ),
        Self(
            id: .minimalImpactOnly,
            displayName: "Minimal Impact Only",
            intent: "Near-silent backswing with timing implied by space and a clean strike confirmation.",
            slots: [
                GuidedSwingAuditionSlot(role: .backswingBuild, assetName: "minimal_impact_backswing", offset: 0, isRequired: false, gain: 0.52),
                GuidedSwingAuditionSlot(role: .impact, assetName: "minimal_impact_impact", offset: 2.00, isRequired: true, gain: 0.72)
            ],
            backswingDuration: 1.60,
            apexSilenceDuration: 0.40,
            impactTrimDuration: 0.24,
            requiresProvenanceManifest: true,
            isRejectedBaseline: false
        )
    ]

    private static func twoSlotLane(_ prefix: String) -> [GuidedSwingAuditionSlot] {
        [
            GuidedSwingAuditionSlot(role: .backswingBuild, assetName: "\(prefix)_backswing", offset: 0, isRequired: true, gain: 0.72),
            GuidedSwingAuditionSlot(role: .impact, assetName: "\(prefix)_impact", offset: 2.00, isRequired: true, gain: 0.72)
        ]
    }
}

enum GuidedSwingSamplePreviewAssetState: String, Equatable, Sendable {
    case present = "Present"
    case missing = "Missing"
    case unreadable = "Unreadable"
}

struct GuidedSwingSamplePreviewAssetResolver {
    let assetURL: (String) -> URL?
    let manifestData: (String) -> Data?
    let canDecode: (URL) -> Bool

    static let bundled = Self(
        assetURL: { name in
            Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "GuidedSwing_Audio")
                ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Garage/GuidedSwing_Audio")
                ?? Bundle.main.url(forResource: name, withExtension: "wav")
        },
        manifestData: { name in
            let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "GuidedSwing_Audio")
                ?? Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Garage/GuidedSwing_Audio")
                ?? Bundle.main.url(forResource: name, withExtension: "json")
            guard let url else { return nil }
            return try? Data(contentsOf: url)
        },
        canDecode: { url in
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return false }
            return player.prepareToPlay()
        }
    )

    func state(for slot: GuidedSwingAuditionSlot) -> GuidedSwingSamplePreviewAssetState {
        guard let url = assetURL(slot.assetName) else { return .missing }
        return canDecode(url) ? .present : .unreadable
    }

    func hasValidManifest(for lane: GuidedSwingAuditionLane) -> Bool {
        guard lane.requiresProvenanceManifest else { return true }
        guard let data = manifestData(GuidedSwingAuditionLane.auditionManifestName) else { return false }
        return GuidedSwingAuditionManifestValidator.isValid(data: data, for: lane)
    }
}

enum GuidedSwingAuditionManifestValidator {
    static func isValid(data: Data, for lane: GuidedSwingAuditionLane) -> Bool {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object)
        else {
            return false
        }

        let searchableText = collectText(from: object).joined(separator: "\n").lowercased()
        let requiredFiles = lane.requiredSlots.map { "\($0.assetName).wav".lowercased() }
        let hasRequiredFiles = requiredFiles.allSatisfy { searchableText.contains($0) }
        let hasSource = searchableText.contains("source")
        let hasLicense = searchableText.contains("license")
        return hasRequiredFiles && hasSource && hasLicense
    }

    private static func collectText(from object: Any) -> [String] {
        if let string = object as? String {
            return [string]
        }
        if let dictionary = object as? [String: Any] {
            return dictionary.flatMap { key, value in
                [key] + collectText(from: value)
            }
        }
        if let array = object as? [Any] {
            return array.flatMap(collectText(from:))
        }
        return []
    }
}

struct GuidedSwingSamplePreviewDefinition {
    static let title = "Guided Swing Audition Library"
    static let lanes = GuidedSwingAuditionLane.all
    static let baselineLane = GuidedSwingAuditionLane.all[0]
    static let slots = baselineLane.slots
    static let backswingEnd: TimeInterval = 1.50
    static let impactOffset: TimeInterval = 2.00
    static let silentTopPause: TimeInterval = impactOffset - backswingEnd
    static let allowsGeneratedFallback = false

    static func states(
        for lane: GuidedSwingAuditionLane = baselineLane,
        using resolver: GuidedSwingSamplePreviewAssetResolver
    ) -> [String: GuidedSwingSamplePreviewAssetState] {
        Dictionary(uniqueKeysWithValues: lane.slots.map { ($0.assetName, resolver.state(for: $0)) })
    }

    static func canPreview(
        _ lane: GuidedSwingAuditionLane = baselineLane,
        using resolver: GuidedSwingSamplePreviewAssetResolver
    ) -> Bool {
        let laneStates = states(for: lane, using: resolver)
        let slotsReady = lane.requiredSlots.allSatisfy { laneStates[$0.assetName] == .present }
        let manifestReady = lane.requiresProvenanceManifest == false
            || resolver.hasValidManifest(for: lane)
        return slotsReady && manifestReady
    }
}

@MainActor
final class GuidedSwingSamplePreviewPlayer: ObservableObject {
    @Published private(set) var slotStates: [String: GuidedSwingSamplePreviewAssetState] = [:]
    @Published private(set) var isPlaying = false
    @Published private(set) var statusText = "Waiting for audition files"
    @Published var selectedLane = GuidedSwingSamplePreviewDefinition.baselineLane {
        didSet {
            stop()
            refreshAvailability()
        }
    }

    private let resolver: GuidedSwingSamplePreviewAssetResolver
    private var players: [AVAudioPlayer] = []
    private var previewTask: Task<Void, Never>?

    init(resolver: GuidedSwingSamplePreviewAssetResolver = .bundled) {
        self.resolver = resolver
        refreshAvailability()
    }

    var canPreview: Bool {
        GuidedSwingSamplePreviewDefinition.canPreview(selectedLane, using: resolver)
    }

    var hasRequiredManifest: Bool {
        selectedLane.requiresProvenanceManifest == false
            || resolver.hasValidManifest(for: selectedLane)
    }

    func refreshAvailability() {
        slotStates = GuidedSwingSamplePreviewDefinition.states(for: selectedLane, using: resolver)
        if isPlaying == false {
            statusText = canPreview ? "\(selectedLane.displayName) ready" : unavailableStatus
        }
    }

    func togglePreview() {
        isPlaying ? stop() : play()
    }

    func stop() {
        previewTask?.cancel()
        previewTask = nil
        stopPlayers()
        isPlaying = false
        statusText = "Preview stopped"
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func play() {
        refreshAvailability()
        guard canPreview else {
            statusText = "Preview unavailable"
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

        isPlaying = true
        statusText = "Playing \(selectedLane.displayName)"
        previewTask = Task { [weak self] in
            guard let self else { return }

            let lane = selectedLane
            if let backswingSlot = lane.slots.first(where: { $0.role == .backswingBuild }),
               slotStates[backswingSlot.assetName] == .present {
                guard await playSlot(backswingSlot, after: backswingSlot.offset) else { return }
            }

            await sleep(seconds: lane.backswingDuration)
            guard Task.isCancelled == false else { return }
            stopPlayers()

            await sleep(seconds: lane.apexSilenceDuration)
            guard Task.isCancelled == false else { return }
            guard let impactSlot = lane.slots.first(where: { $0.role == .impact }) else { return }
            guard playSlot(impactSlot) else { return }

            await sleep(seconds: lane.impactTrimDuration)
            guard Task.isCancelled == false else { return }
            finishPlayback()
        }
    }

    private func playSlot(_ slot: GuidedSwingAuditionSlot, after delay: TimeInterval) async -> Bool {
        await sleep(seconds: delay)
        guard Task.isCancelled == false else { return false }
        return playSlot(slot)
    }

    @discardableResult
    private func playSlot(_ slot: GuidedSwingAuditionSlot) -> Bool {
        guard
            let url = resolver.assetURL(slot.assetName),
            resolver.canDecode(url),
            let player = try? AVAudioPlayer(contentsOf: url),
            player.prepareToPlay()
        else {
            stopPlayers()
            isPlaying = false
            refreshAvailability()
            statusText = "Could not decode \(slot.assetName).wav"
            return false
        }

        player.volume = Float(slot.gain)
        players.removeAll { $0.isPlaying == false }
        players.append(player)
        player.play()
        return true
    }

    private func stopPlayers() {
        players.forEach { $0.stop() }
        players.removeAll()
    }

    private func finishPlayback() {
        stopPlayers()
        previewTask = nil
        isPlaying = false
        statusText = "Preview complete"
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private var unavailableStatus: String {
        if hasRequiredManifest == false {
            return "Missing or invalid audition source manifest"
        }
        return "Samples missing or unreadable"
    }

    private func sleep(seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

struct GuidedSwingSamplePreviewSection: View {
    @ObservedObject var player: GuidedSwingSamplePreviewPlayer
    let onPreviewStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(GuidedSwingSamplePreviewDefinition.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text("DEBUG tasting room · real WAV samples only")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }

            Divider().overlay(GarageProTheme.border)

            lanePicker

            laneSummary

            ForEach(player.selectedLane.slots) { slot in
                slotRow(slot)
            }

            provenanceRow

            Text(timingSummary)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GarageProTheme.textSecondary)

            Text("These lanes do not replace live Guided Swing.")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(GaragePremiumPalette.gold)

            HStack(spacing: 10) {
                Text(player.statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)

                Spacer(minLength: 8)

                Button(player.isPlaying ? "Stop" : "Preview") {
                    if player.isPlaying == false {
                        onPreviewStart()
                    }
                    player.togglePreview()
                }
                .buttonStyle(GarageSamplePreviewButtonStyle(isActive: player.isPlaying))
                .disabled(player.canPreview == false && player.isPlaying == false)
                .accessibilityHint(player.canPreview ? "Plays the selected audition lane" : "Requires present, decodable WAV files and strict provenance")
            }
        }
        .padding(.vertical, 4)
        .onAppear { player.refreshAvailability() }
    }

    private var lanePicker: some View {
        VStack(spacing: 8) {
            ForEach(GuidedSwingSamplePreviewDefinition.lanes) { lane in
                Button {
                    player.selectedLane = lane
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(lane.displayName)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(GarageProTheme.textPrimary)
                            Text(lane.isRejectedBaseline ? "Comparison baseline" : "Candidate lane")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(GarageProTheme.textSecondary)
                        }

                        Spacer()

                        if player.selectedLane.id == lane.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(GaragePremiumPalette.gold)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        player.selectedLane.id == lane.id ? GaragePremiumPalette.gold.opacity(0.10) : GarageProTheme.insetSurface,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var laneSummary: some View {
        Text(player.selectedLane.intent)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(GarageProTheme.textSecondary)
    }

    private var provenanceRow: some View {
        HStack(spacing: 10) {
            Text("\(GuidedSwingAuditionLane.auditionManifestName).json")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(GarageProTheme.textPrimary)

            Spacer(minLength: 8)

            Label(player.hasRequiredManifest ? "Ready" : "Required", systemImage: player.hasRequiredManifest ? "checkmark.circle.fill" : "doc.badge.plus")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(player.hasRequiredManifest ? GaragePremiumPalette.mintText : GarageProTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var timingSummary: String {
        let lane = player.selectedLane
        return "Build \(lane.backswingDuration.formatted(.number.precision(.fractionLength(2))))s · silence \(lane.apexSilenceDuration.formatted(.number.precision(.fractionLength(2))))s · impact trim \(lane.impactTrimDuration.formatted(.number.precision(.fractionLength(2))))s."
    }

    private func slotRow(_ slot: GuidedSwingAuditionSlot) -> some View {
        let state = player.slotStates[slot.assetName] ?? .missing

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(slot.assetName).wav")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(GarageProTheme.textPrimary)

                Text(slot.isRequired ? slot.role.title : "\(slot.role.title) optional")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(GarageProTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Label(state.rawValue, systemImage: statusSymbol(state))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(statusColor(state))
        }
        .accessibilityElement(children: .combine)
    }

    private func statusSymbol(_ state: GuidedSwingSamplePreviewAssetState) -> String {
        switch state {
        case .present: "checkmark.circle.fill"
        case .missing: "minus.circle"
        case .unreadable: "exclamationmark.triangle.fill"
        }
    }

    private func statusColor(_ state: GuidedSwingSamplePreviewAssetState) -> Color {
        switch state {
        case .present: GaragePremiumPalette.mintText
        case .missing: GarageProTheme.textSecondary
        case .unreadable: .orange
        }
    }
}

private struct GarageSamplePreviewButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(isActive ? GaragePremiumPalette.emeraldDeep : GarageProTheme.textPrimary)
            .frame(minWidth: 76, minHeight: 44)
            .background(isActive ? GaragePremiumPalette.gold : GarageProTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(GarageProTheme.border, lineWidth: isActive ? 0 : 1))
            .opacity(configuration.isPressed ? 0.76 : 1)
    }
}
#endif
