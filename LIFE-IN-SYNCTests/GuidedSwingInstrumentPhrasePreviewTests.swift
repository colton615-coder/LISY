#if DEBUG
import Foundation
import Testing
@testable import LIFE_IN_SYNC

struct GuidedSwingInstrumentPhrasePreviewTests {
    @Test func previewUsesExactlyTwoProductionSampleSlots() {
        #expect(GuidedSwingSamplePreviewDefinition.title == "Premium Lift Hill")
        #expect(GuidedSwingSamplePreviewDefinition.slots.map(\.rawValue) == [
            "backswing_premium_lift_hill",
            "impact_golf_swing"
        ])
    }

    @Test func previewUsesApprovedTimingAndSilentBoundary() {
        #expect(GuidedSwingSamplePreviewDefinition.slots.map(\.offset) == [0.00, 2.00])
        #expect(GuidedSwingSamplePreviewDefinition.backswingEnd == 1.50)
        #expect(GuidedSwingSamplePreviewDefinition.impactOffset == 2.00)
        #expect(abs(GuidedSwingSamplePreviewDefinition.silentTopPause - 0.50) < 0.000_001)
    }

    @Test func missingOrUnreadableAssetsBlockPreview() {
        let urls = Dictionary(uniqueKeysWithValues: GuidedSwingSamplePreviewDefinition.slots.map { slot in
            (slot.rawValue, URL(fileURLWithPath: "/tmp/\(slot.rawValue).wav"))
        })
        let missingResolver = GuidedSwingSamplePreviewAssetResolver(
            assetURL: { name in name == "impact_golf_swing" ? nil : urls[name] },
            canDecode: { _ in true }
        )
        let unreadableResolver = GuidedSwingSamplePreviewAssetResolver(
            assetURL: { urls[$0] },
            canDecode: { $0.lastPathComponent != "backswing_premium_lift_hill.wav" }
        )

        #expect(GuidedSwingSamplePreviewDefinition.canPreview(using: missingResolver) == false)
        #expect(GuidedSwingSamplePreviewDefinition.states(using: missingResolver)[.impactGolfSwing] == .missing)
        #expect(GuidedSwingSamplePreviewDefinition.canPreview(using: unreadableResolver) == false)
        #expect(GuidedSwingSamplePreviewDefinition.states(using: unreadableResolver)[.backswingPremiumLiftHill] == .unreadable)
    }

    @Test func allDecodableAssetsEnablePreview() {
        let resolver = GuidedSwingSamplePreviewAssetResolver(
            assetURL: { URL(fileURLWithPath: "/tmp/\($0).wav") },
            canDecode: { _ in true }
        )

        #expect(GuidedSwingSamplePreviewDefinition.canPreview(using: resolver))
        #expect(GuidedSwingSamplePreviewDefinition.states(using: resolver).values.allSatisfy { $0 == .present })
    }

    @Test func previewExplicitlyDisallowsGeneratedFallback() {
        #expect(GuidedSwingSamplePreviewDefinition.allowsGeneratedFallback == false)
    }
}
#endif
