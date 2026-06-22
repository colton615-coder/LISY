#if DEBUG
import Foundation
import Testing
@testable import LIFE_IN_SYNC

struct GuidedSwingInstrumentPhrasePreviewTests {
    @Test func previewUsesExactlyFourNeutralSampleSlots() {
        #expect(GuidedSwingSamplePreviewDefinition.title == "Muted Rhodes Timing Cue")
        #expect(GuidedSwingSamplePreviewDefinition.slots.map(\.rawValue) == [
            "backswing_01",
            "backswing_02",
            "backswing_03",
            "impact_confirm"
        ])
    }

    @Test func previewUsesApprovedTimingAndSilentBoundary() {
        #expect(GuidedSwingSamplePreviewDefinition.slots.map(\.offset) == [0.00, 0.58, 1.16, 1.90])
        #expect(GuidedSwingSamplePreviewDefinition.backswingEnd == 1.74)
        #expect(abs(GuidedSwingSamplePreviewDefinition.silentTopPause - 0.16) < 0.000_001)
    }

    @Test func missingOrUnreadableAssetsBlockPreview() {
        let urls = Dictionary(uniqueKeysWithValues: GuidedSwingSamplePreviewDefinition.slots.map { slot in
            (slot.rawValue, URL(fileURLWithPath: "/tmp/\(slot.rawValue).wav"))
        })
        let missingResolver = GuidedSwingSamplePreviewAssetResolver(
            assetURL: { name in name == "impact_confirm" ? nil : urls[name] },
            canDecode: { _ in true }
        )
        let unreadableResolver = GuidedSwingSamplePreviewAssetResolver(
            assetURL: { urls[$0] },
            canDecode: { $0.lastPathComponent != "backswing_02.wav" }
        )

        #expect(GuidedSwingSamplePreviewDefinition.canPreview(using: missingResolver) == false)
        #expect(GuidedSwingSamplePreviewDefinition.states(using: missingResolver)[.impactConfirm] == .missing)
        #expect(GuidedSwingSamplePreviewDefinition.canPreview(using: unreadableResolver) == false)
        #expect(GuidedSwingSamplePreviewDefinition.states(using: unreadableResolver)[.backswing02] == .unreadable)
    }

    @Test func allFourDecodableAssetsEnablePreview() {
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
