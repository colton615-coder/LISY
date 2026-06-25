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
            let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            JSONSerialization.isValidJSONObject(manifest)
        else {
            return false
        }

        return hasValidSchemaVersion(in: manifest)
            && stringValue(manifest["scope"]) == "debug_only_guided_swing_audition"
            && packet(in: manifest, for: lane).map { isValid(packet: $0, for: lane) } == true
    }

    private static func packet(in manifest: [String: Any], for lane: GuidedSwingAuditionLane) -> [String: Any]? {
        guard let packets = manifest["candidate_packets"] as? [[String: Any]] else { return nil }
        return packets.first { stringValue($0["lane_id"]) == lane.id.rawValue }
    }

    private static func isValid(packet: [String: Any], for lane: GuidedSwingAuditionLane) -> Bool {
        guard
            hasNonEmptyString(packet["packet_id"]),
            stringValue(packet["lane_id"]) == lane.id.rawValue,
            hasNonEmptyString(packet["display_name"]),
            ["proposed", "rejected", "approved_for_debug_audition"].contains(stringValue(packet["status"]) ?? ""),
            stringValue(packet["scope"]) == "debug_only_guided_swing_audition",
            stringValue(packet["install_policy"]) == "not_live_guided_swing",
            stringValue(packet["fallback_policy"]) == "none",
            stringValue(packet["source_material_type"]) == "recorded_sample",
            let slots = packet["required_slots"] as? [[String: Any]],
            let timing = packet["timing"] as? [String: Any],
            let source = packet["source"] as? [String: Any],
            let sourceFile = packet["source_file"] as? [String: Any],
            let edits = packet["edits"] as? [[String: Any]],
            let finalAssets = packet["final_assets"] as? [[String: Any]],
            let tasteReview = packet["taste_review"] as? [String: Any],
            let legalReview = packet["legal_review"] as? [String: Any]
        else {
            return false
        }

        return requiredSlotsAreValid(slots, for: lane)
            && timingIsValid(timing)
            && sourceIsValid(source)
            && sourceFileIsValid(sourceFile)
            && editsAreValid(edits, for: lane)
            && finalAssetsAreValid(finalAssets, for: lane)
            && tasteReviewIsValid(tasteReview)
            && legalReviewIsValid(legalReview)
    }

    private static func hasValidSchemaVersion(in manifest: [String: Any]) -> Bool {
        guard let schemaVersion = stringValue(manifest["schema_version"]) else { return false }
        return schemaVersion.isEmpty == false
    }

    private static func requiredSlotsAreValid(_ slots: [[String: Any]], for lane: GuidedSwingAuditionLane) -> Bool {
        let requiredSlots = slots.filter { boolValue($0["required"]) == true }
        guard requiredSlots.count == lane.requiredSlots.count else { return false }

        return lane.requiredSlots.allSatisfy { laneSlot in
            let expectedFilename = "\(laneSlot.assetName).wav"
            let expectedRole = manifestRole(for: laneSlot.role)
            guard let slot = requiredSlots.first(where: { stringValue($0["filename"]) == expectedFilename }) else {
                return false
            }
            return stringValue(slot["role"]) == expectedRole
                && boolValue(slot["required"]) == true
                && numberValue(slot["offset_seconds"]) != nil
                && positiveNumberValue(slot["duration_target_seconds"]) != nil
                && numberValue(slot["gain_db"]) != nil
        }
    }

    private static func timingIsValid(_ timing: [String: Any]) -> Bool {
        positiveNumberValue(timing["backswing_duration_seconds"]) != nil
            && positiveNumberValue(timing["top_silence_duration_seconds"]) != nil
            && positiveNumberValue(timing["impact_offset_seconds"]) != nil
            && positiveNumberValue(timing["impact_trim_duration_seconds"]) != nil
    }

    private static func sourceIsValid(_ source: [String: Any]) -> Bool {
        hasNonEmptyString(source["source_url"])
            && hasNonEmptyString(source["direct_media_url"])
            && hasNonEmptyString(source["author"])
            && hasNonEmptyString(source["publisher_or_library"])
            && hasNonEmptyString(source["license_name"])
            && stringValue(source["license_name"])?.localizedCaseInsensitiveContains("unknown") == false
            && hasNonEmptyString(source["license_url"])
            && boolValue(source["attribution_required"]) != nil
            && hasNonEmptyString(source["attribution_text"])
            && boolValue(source["redistribution_allowed"]) == true
    }

    private static func sourceFileIsValid(_ sourceFile: [String: Any]) -> Bool {
        hasNonEmptyString(sourceFile["original_filename"])
            && isSHA256(sourceFile["source_sha256"])
            && hasNonEmptyString(sourceFile["format"])
            && sourceFile.keys.contains("sample_rate_hz")
            && sourceFile.keys.contains("channels")
            && sourceFile.keys.contains("bit_depth")
            && positiveNumberValue(sourceFile["duration_seconds"]) != nil
    }

    private static func editsAreValid(_ edits: [[String: Any]], for lane: GuidedSwingAuditionLane) -> Bool {
        lane.requiredSlots.allSatisfy { laneSlot in
            let expectedRole = manifestRole(for: laneSlot.role)
            guard let edit = edits.first(where: { stringValue($0["role"]) == expectedRole }) else {
                return false
            }
            return numberValue(edit["source_start_seconds"]) != nil
                && positiveNumberValue(edit["source_end_seconds"]) != nil
                && numberValue(edit["final_trim_start_seconds"]) != nil
                && positiveNumberValue(edit["final_trim_end_seconds"]) != nil
                && numberValue(edit["fade_in_seconds"]) != nil
                && numberValue(edit["fade_out_seconds"]) != nil
                && hasNonEmptyString(edit["conversion_notes"])
                && hasNonEmptyString(edit["normalization_notes"])
                && hasNonEmptyString(edit["downmix_notes"])
        }
    }

    private static func finalAssetsAreValid(_ finalAssets: [[String: Any]], for lane: GuidedSwingAuditionLane) -> Bool {
        lane.requiredSlots.allSatisfy { laneSlot in
            let expectedFilename = "\(laneSlot.assetName).wav"
            let expectedRole = manifestRole(for: laneSlot.role)
            guard let asset = finalAssets.first(where: { stringValue($0["filename"]) == expectedFilename }) else {
                return false
            }
            return stringValue(asset["role"]) == expectedRole
                && isSHA256(asset["sha256"])
                && positiveNumberValue(asset["duration_seconds"]) != nil
                && hasNonEmptyString(asset["format"])
                && numberValue(asset["peak_target_dbfs"]) != nil
                && numberValue(asset["peak_result_dbfs"]) != nil
                && hasNonEmptyString(asset["afinfo_checked_date"])
        }
    }

    private static func tasteReviewIsValid(_ review: [String: Any]) -> Bool {
        guard
            hasNonEmptyString(review["intended_character"]),
            hasNonEmptyString(review["guided_swing_fit_reason"]),
            hasNonEmptyString(review["physical_iphone_listening_status"]),
            hasNonEmptyString(review["taste_reviewed_by"]),
            hasNonEmptyString(review["taste_reviewed_date"]),
            let risks = review["rejected_character_risks"] as? [String]
        else {
            return false
        }

        let requiredRisks = [
            "childish",
            "toy-like",
            "arcade",
            "sci-fi sweep",
            "oscillator drone",
            "raw clank/snap/thump collage",
            "noisy impact stack",
            "wind/breath/exhale",
            "metronome-like click bed",
            "filled top silence"
        ]
        let normalizedRisks = Set(risks.map { $0.lowercased() })
        return requiredRisks.allSatisfy { normalizedRisks.contains($0) }
    }

    private static func legalReviewIsValid(_ review: [String: Any]) -> Bool {
        guard
            let decision = stringValue(review["license_decision"]),
            ["accepted_for_debug_audition", "rejected", "needs_review"].contains(decision),
            hasNonEmptyString(review["reason"]),
            hasNonEmptyString(review["legal_reviewed_by"]),
            hasNonEmptyString(review["legal_reviewed_date"])
        else {
            return false
        }
        return true
    }

    private static func manifestRole(for role: GuidedSwingAuditionSlotRole) -> String {
        switch role {
        case .backswingBuild: "backswing"
        case .impact: "impact"
        }
    }

    private static func hasNonEmptyString(_ value: Any?) -> Bool {
        guard let string = stringValue(value) else { return false }
        return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private static func stringValue(_ value: Any?) -> String? {
        value as? String
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        value as? Bool
    }

    private static func numberValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return value as? Double
    }

    private static func positiveNumberValue(_ value: Any?) -> Double? {
        guard let number = numberValue(value), number > 0 else { return nil }
        return number
    }

    private static func isSHA256(_ value: Any?) -> Bool {
        guard let string = stringValue(value) else { return false }
        return string.range(of: "^[a-fA-F0-9]{64}$", options: .regularExpression) != nil
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
