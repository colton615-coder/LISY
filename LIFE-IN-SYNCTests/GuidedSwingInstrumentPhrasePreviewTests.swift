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

    @Test func previewExplicitlyDisallowsGeneratedFallback() {
        #expect(GuidedSwingSamplePreviewDefinition.allowsGeneratedFallback == false)
        #expect(TempoSoundIdentityProfile.allCases == [.premiumLiftHill])
        #expect(GarageGuidedSwingProfile.qaListeningOrder == [.premiumLiftHill])
    }

    private func validManifestData(for lane: GuidedSwingAuditionLane) -> Data {
        let assets = lane.requiredSlots.map { slot in
            """
            {
              "filename": "\(slot.assetName).wav",
              "source_url": "local://manual-audition/\(slot.assetName).wav",
              "source_author": "Manual audition source",
              "source_license": "Document before use"
            }
            """
        }.joined(separator: ",")
        return #"{"assets":["#
            .appending(assets)
            .appending(#"]}"#)
            .data(using: .utf8)!
    }
}
#endif
