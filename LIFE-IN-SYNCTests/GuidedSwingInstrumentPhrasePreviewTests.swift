#if DEBUG
import Foundation
import Testing
@testable import LIFE_IN_SYNC

struct GuidedSwingInstrumentPhrasePreviewTests {
    @Test func previewKeepsRejectedPremiumLiftHillAsComparisonBaseline() {
        #expect(GuidedSwingSamplePreviewDefinition.title == "Guided Swing Audition Library")
        #expect(GuidedSwingSamplePreviewDefinition.baselineLane.isRejectedBaseline)
        #expect(GuidedSwingSamplePreviewDefinition.baselineLane.displayName == "Baseline: Premium Lift Hill")
        #expect(GuidedSwingSamplePreviewDefinition.baselineLane.slots.map(\.assetName) == [
            "backswing_premium_lift_hill",
            "impact_golf_swing"
        ])
        #expect(GuidedSwingSamplePreviewDefinition.baselineLane.requiresProvenanceManifest == false)
    }

    @Test func baselineUsesApprovedTimingAndSilentBoundary() {
        #expect(GuidedSwingSamplePreviewDefinition.baselineLane.slots.map(\.offset) == [0.00, 2.00])
        #expect(GuidedSwingSamplePreviewDefinition.backswingEnd == 1.50)
        #expect(GuidedSwingSamplePreviewDefinition.impactOffset == 2.00)
        #expect(abs(GuidedSwingSamplePreviewDefinition.silentTopPause - 0.50) < 0.000_001)
    }

    @Test func auditionLibraryDeclaresEveryRequestedCandidateLane() {
        #expect(GuidedSwingSamplePreviewDefinition.lanes.map(\.id) == [
            .rejectedPremiumLiftHillBaseline,
            .apexLift,
            .cableWinch,
            .torqueRatchet,
            .hydraulicLoad,
            .trackLock,
            .tourMechanism,
            .minimalImpactOnly
        ])
        #expect(GuidedSwingSamplePreviewDefinition.lanes.allSatisfy { $0.displayName.isEmpty == false })
        #expect(GuidedSwingSamplePreviewDefinition.lanes.allSatisfy { $0.intent.isEmpty == false })
    }

    @Test func auditionCandidatesDeclareExpectedAssetSlotsAndStrictManifest() {
        let candidateLanes = GuidedSwingSamplePreviewDefinition.lanes.filter { $0.isRejectedBaseline == false }

        #expect(candidateLanes.allSatisfy(\.requiresProvenanceManifest))
        #expect(GuidedSwingAuditionLane.auditionManifestName == "GUIDED_SWING_AUDITION_SOURCE_MANIFEST")
        #expect(candidateLanes.first { $0.id == .apexLift }?.expectedAssetNames == [
            "apex_lift_backswing",
            "apex_lift_impact"
        ])
        #expect(candidateLanes.first { $0.id == .cableWinch }?.expectedAssetNames == [
            "cable_winch_backswing",
            "cable_winch_impact"
        ])
        #expect(candidateLanes.first { $0.id == .torqueRatchet }?.expectedAssetNames == [
            "torque_ratchet_backswing",
            "torque_ratchet_impact"
        ])
        #expect(candidateLanes.first { $0.id == .hydraulicLoad }?.expectedAssetNames == [
            "hydraulic_load_backswing",
            "hydraulic_load_impact"
        ])
        #expect(candidateLanes.first { $0.id == .trackLock }?.expectedAssetNames == [
            "track_lock_backswing",
            "track_lock_impact"
        ])
        #expect(candidateLanes.first { $0.id == .tourMechanism }?.expectedAssetNames == [
            "tour_mechanism_backswing",
            "tour_mechanism_impact"
        ])

        let minimalImpact = candidateLanes.first { $0.id == .minimalImpactOnly }
        #expect(minimalImpact?.expectedAssetNames == [
            "minimal_impact_backswing",
            "minimal_impact_impact"
        ])
        #expect(minimalImpact?.slots.first { $0.assetName == "minimal_impact_backswing" }?.isRequired == false)
        #expect(minimalImpact?.requiredSlots.map(\.assetName) == ["minimal_impact_impact"])
    }

    @Test func missingOrUnreadableAssetsBlockPreview() {
        let baselineLane = GuidedSwingSamplePreviewDefinition.baselineLane
        let urls = Dictionary(uniqueKeysWithValues: baselineLane.slots.map { slot in
            (slot.assetName, URL(fileURLWithPath: "/tmp/\(slot.assetName).wav"))
        })
        let missingResolver = GuidedSwingSamplePreviewAssetResolver(
            assetURL: { name in name == "impact_golf_swing" ? nil : urls[name] },
            manifestData: { _ in validManifestData(for: baselineLane) },
            canDecode: { _ in true }
        )
        let unreadableResolver = GuidedSwingSamplePreviewAssetResolver(
            assetURL: { urls[$0] },
            manifestData: { _ in validManifestData(for: baselineLane) },
            canDecode: { $0.lastPathComponent != "backswing_premium_lift_hill.wav" }
        )

        #expect(GuidedSwingSamplePreviewDefinition.canPreview(baselineLane, using: missingResolver) == false)
        #expect(GuidedSwingSamplePreviewDefinition.states(for: baselineLane, using: missingResolver)["impact_golf_swing"] == .missing)
        #expect(GuidedSwingSamplePreviewDefinition.canPreview(baselineLane, using: unreadableResolver) == false)
        #expect(GuidedSwingSamplePreviewDefinition.states(for: baselineLane, using: unreadableResolver)["backswing_premium_lift_hill"] == .unreadable)
    }

    @Test func allDecodableBaselineAssetsEnablePreview() {
        let resolver = GuidedSwingSamplePreviewAssetResolver(
            assetURL: { URL(fileURLWithPath: "/tmp/\($0).wav") },
            manifestData: { _ in nil },
            canDecode: { _ in true }
        )

        #expect(GuidedSwingSamplePreviewDefinition.canPreview(using: resolver))
        #expect(GuidedSwingSamplePreviewDefinition.states(using: resolver).values.allSatisfy { $0 == .present })
    }

    @Test func candidatePreviewRequiresManifestEvenWhenAssetsDecode() {
        let lane = GuidedSwingSamplePreviewDefinition.lanes.first { $0.id == .cableWinch }!
        let noManifestResolver = GuidedSwingSamplePreviewAssetResolver(
            assetURL: { URL(fileURLWithPath: "/tmp/\($0).wav") },
            manifestData: { _ in nil },
            canDecode: { _ in true }
        )
        let manifestResolver = GuidedSwingSamplePreviewAssetResolver(
            assetURL: { URL(fileURLWithPath: "/tmp/\($0).wav") },
            manifestData: { _ in validManifestData(for: lane) },
            canDecode: { _ in true }
        )
        let invalidManifestResolver = GuidedSwingSamplePreviewAssetResolver(
            assetURL: { URL(fileURLWithPath: "/tmp/\($0).wav") },
            manifestData: { _ in #"{"assets":["cable_winch_backswing.wav"]}"#.data(using: .utf8) },
            canDecode: { _ in true }
        )

        #expect(GuidedSwingSamplePreviewDefinition.canPreview(lane, using: noManifestResolver) == false)
        #expect(GuidedSwingSamplePreviewDefinition.canPreview(lane, using: manifestResolver))
        #expect(GuidedSwingSamplePreviewDefinition.canPreview(lane, using: invalidManifestResolver) == false)
    }

    @Test func structuredAuditionManifestRejectsUnsafeOrIncompletePackets() {
        let lane = GuidedSwingSamplePreviewDefinition.lanes.first { $0.id == .cableWinch }!

        #expect(GuidedSwingAuditionManifestValidator.isValid(data: validManifestData(for: lane), for: lane))
        #expect(isInvalidManifest(for: lane) { remove("license_url", from: "source", in: &$0) })
        #expect(isInvalidManifest(for: lane) { remove("attribution_required", from: "source", in: &$0) })
        #expect(isInvalidManifest(for: lane) { remove("redistribution_allowed", from: "source", in: &$0) })
        #expect(isInvalidManifest(for: lane) { remove("source_sha256", from: "source_file", in: &$0) })
        #expect(isInvalidManifest(for: lane) { remove("duration_seconds", from: "source_file", in: &$0) })
        #expect(isInvalidManifest(for: lane) { remove("format", from: "source_file", in: &$0) })
        #expect(isInvalidManifest(for: lane) { remove("sha256", fromFinalAssetAt: 0, in: &$0) })
        #expect(isInvalidManifest(for: lane) { remove("duration_seconds", fromFinalAssetAt: 0, in: &$0) })
        #expect(isInvalidManifest(for: lane) { remove("format", fromFinalAssetAt: 0, in: &$0) })
        #expect(isInvalidManifest(for: lane) { remove("afinfo_checked_date", fromFinalAssetAt: 0, in: &$0) })
        #expect(isInvalidManifest(for: lane) { $0["fallback_policy"] = "generated_fallback" })
        #expect(isInvalidManifest(for: lane) { $0["install_policy"] = "install_into_live_guided_swing" })
        #expect(isInvalidManifest(for: lane) { removeRequiredSlot(named: "cable_winch_impact.wav", in: &$0) })
        #expect(isInvalidManifest(for: lane) { $0["source_material_type"] = "generated_synthetic" })
    }

    @Test func previewExplicitlyDisallowsGeneratedFallback() {
        #expect(GuidedSwingSamplePreviewDefinition.allowsGeneratedFallback == false)
        #expect(TempoSoundIdentityProfile.allCases == [.premiumLiftHill])
        #expect(GarageGuidedSwingProfile.qaListeningOrder == [.premiumLiftHill])
    }

    private func validManifestData(for lane: GuidedSwingAuditionLane) -> Data {
        let object: [String: Any] = [
            "schema_version": "1.0",
            "manifest_name": "Guided Swing DEBUG Audition Source Manifest",
            "scope": "debug_only_guided_swing_audition",
            "candidate_packets": [validPacket(for: lane)]
        ]
        return try! JSONSerialization.data(withJSONObject: object)
    }

    private func invalidManifestData(
        for lane: GuidedSwingAuditionLane,
        mutatePacket: (inout [String: Any]) -> Void
    ) -> Data {
        var packet = validPacket(for: lane)
        mutatePacket(&packet)
        let object: [String: Any] = [
            "schema_version": "1.0",
            "manifest_name": "Guided Swing DEBUG Audition Source Manifest",
            "scope": "debug_only_guided_swing_audition",
            "candidate_packets": [packet]
        ]
        return try! JSONSerialization.data(withJSONObject: object)
    }

    private func isInvalidManifest(
        for lane: GuidedSwingAuditionLane,
        mutatePacket: (inout [String: Any]) -> Void
    ) -> Bool {
        GuidedSwingAuditionManifestValidator.isValid(
            data: invalidManifestData(for: lane, mutatePacket: mutatePacket),
            for: lane
        ) == false
    }

    private func validPacket(for lane: GuidedSwingAuditionLane) -> [String: Any] {
        [
            "packet_id": "guided_swing_audition_\(lane.id.rawValue)_candidate_01",
            "lane_id": lane.id.rawValue,
            "display_name": lane.displayName,
            "status": "approved_for_debug_audition",
            "scope": "debug_only_guided_swing_audition",
            "install_policy": "not_live_guided_swing",
            "fallback_policy": "none",
            "source_material_type": "recorded_sample",
            "required_slots": lane.requiredSlots.map(validSlot),
            "timing": [
                "backswing_duration_seconds": lane.backswingDuration,
                "top_silence_duration_seconds": lane.apexSilenceDuration,
                "impact_offset_seconds": lane.impactOffset,
                "impact_trim_duration_seconds": lane.impactTrimDuration
            ],
            "source": [
                "source_url": "local://manual-audition/source",
                "direct_media_url": "local://manual-audition/source-media",
                "author": "Manual audition source",
                "publisher_or_library": "Manual audition library",
                "license_name": "Creative Commons Attribution 3.0 Unported (CC BY 3.0)",
                "license_url": "https://creativecommons.org/licenses/by/3.0/deed.en",
                "attribution_required": true,
                "attribution_text": "Manual audition source, licensed under CC BY 3.0.",
                "redistribution_allowed": true
            ],
            "source_file": [
                "original_filename": "manual-source.webm",
                "source_sha256": "51c589860418ffe2332a369e6e714b92afe7e8af9376c1932bed7dda95e0ad73",
                "format": "WebM audio/video, VP9/Opus",
                "sample_rate_hz": NSNull(),
                "channels": NSNull(),
                "bit_depth": NSNull(),
                "duration_seconds": 36.277
            ],
            "edits": lane.requiredSlots.map(validEdit),
            "final_assets": lane.requiredSlots.map(validFinalAsset),
            "taste_review": [
                "intended_character": "Controlled mechanical audition source.",
                "guided_swing_fit_reason": "Supports backswing load, true top silence, and compact impact confirmation.",
                "rejected_character_risks": [
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
                ],
                "physical_iphone_listening_status": "not_performed_for_test_fixture",
                "taste_reviewed_by": "Test fixture",
                "taste_reviewed_date": "2026-06-25"
            ],
            "legal_review": [
                "license_decision": "accepted_for_debug_audition",
                "reason": "Fixture records DEBUG audition rights only.",
                "legal_reviewed_by": "Test fixture",
                "legal_reviewed_date": "2026-06-25"
            ]
        ]
    }

    private func validSlot(for slot: GuidedSwingAuditionSlot) -> [String: Any] {
        [
            "role": manifestRole(for: slot.role),
            "filename": "\(slot.assetName).wav",
            "required": true,
            "offset_seconds": slot.offset,
            "duration_target_seconds": slot.role == .backswingBuild ? 1.7 : 0.28,
            "gain_db": -2.85
        ]
    }

    private func validEdit(for slot: GuidedSwingAuditionSlot) -> [String: Any] {
        [
            "role": manifestRole(for: slot.role),
            "source_start_seconds": slot.role == .backswingBuild ? 28.6 : 16.8,
            "source_end_seconds": slot.role == .backswingBuild ? 30.3 : 17.08,
            "final_trim_start_seconds": 0.0,
            "final_trim_end_seconds": slot.role == .backswingBuild ? 1.7 : 0.28,
            "fade_in_seconds": slot.role == .backswingBuild ? 0.022 : 0.002,
            "fade_out_seconds": slot.role == .backswingBuild ? 0.055 : 0.045,
            "conversion_notes": "Converted source media to WAV.",
            "normalization_notes": "Peak-normalized for DEBUG audition playback.",
            "downmix_notes": "Downmixed source media to mono."
        ]
    }

    private func validFinalAsset(for slot: GuidedSwingAuditionSlot) -> [String: Any] {
        [
            "role": manifestRole(for: slot.role),
            "filename": "\(slot.assetName).wav",
            "sha256": slot.role == .backswingBuild
                ? "c8055cca72ed045f300ffab64713d61daf656f312c316e77992ba3e5b843d7df"
                : "eef1daf10606a44e683a7b64e888ed53cddba609614bb189388d5904f8ec5f00",
            "duration_seconds": slot.role == .backswingBuild ? 1.7 : 0.28,
            "format": "mono 44.1 kHz 16-bit PCM WAV",
            "peak_target_dbfs": slot.role == .backswingBuild ? -2.16 : -3.35,
            "peak_result_dbfs": slot.role == .backswingBuild ? -2.158 : -3.35,
            "afinfo_checked_date": "2026-06-25"
        ]
    }

    private func manifestRole(for role: GuidedSwingAuditionSlotRole) -> String {
        switch role {
        case .backswingBuild: "backswing"
        case .impact: "impact"
        }
    }

    private func remove(_ key: String, from nestedKey: String, in packet: inout [String: Any]) {
        var nested = packet[nestedKey] as! [String: Any]
        nested.removeValue(forKey: key)
        packet[nestedKey] = nested
    }

    private func remove(_ key: String, fromFinalAssetAt index: Int, in packet: inout [String: Any]) {
        var assets = packet["final_assets"] as! [[String: Any]]
        assets[index].removeValue(forKey: key)
        packet["final_assets"] = assets
    }

    private func removeRequiredSlot(named filename: String, in packet: inout [String: Any]) {
        let slots = packet["required_slots"] as! [[String: Any]]
        packet["required_slots"] = slots.filter { $0["filename"] as? String != filename }
    }
}
#endif
