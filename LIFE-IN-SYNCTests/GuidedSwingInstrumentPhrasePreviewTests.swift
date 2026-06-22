#if DEBUG
import Testing
@testable import LIFE_IN_SYNC

struct GuidedSwingInstrumentPhrasePreviewTests {
    @Test func candidatesHaveFixedRankAndSourcingPriority() {
        let candidates = GuidedSwingInstrumentPhraseCandidate.allCases

        #expect(candidates.map(\.rank) == [1, 2, 3, 4, 5, 6])
        #expect(candidates.map(\.sourcingPriority) == [.primary, .secondary, .secondary, .exploratory, .exploratory, .specOnly])
        #expect(candidates.first == .mutedRhodes)
    }

    @Test func mutedRhodesUsesTheApprovedMusicalAndAssetContract() {
        let candidate = GuidedSwingInstrumentPhraseCandidate.mutedRhodes

        #expect(candidate.musicalMap == "A3 → C4 → D4 → silence → A3/D4")
        #expect(candidate.requiredAssetNames == [
            "muted_rhodes_01_A3",
            "muted_rhodes_02_C4",
            "muted_rhodes_03_D4",
            "muted_rhodes_impact_A3_D4"
        ])
    }

    @Test func playableCandidatesUseTheFixedPhraseTiming() {
        let playableCandidates = GuidedSwingInstrumentPhraseCandidate.allCases.filter { $0.isSpecOnly == false }

        #expect(GuidedSwingInstrumentPhraseCandidate.eventOffsets == [0.00, 0.58, 1.16, 1.90])
        #expect(GuidedSwingInstrumentPhraseCandidate.backswingEnd == 1.74)
        #expect(GuidedSwingInstrumentPhraseCandidate.silentTopPause == 0.16)
        let measuredPause = GuidedSwingInstrumentPhraseCandidate.eventOffsets.last! - GuidedSwingInstrumentPhraseCandidate.backswingEnd
        #expect(abs(measuredPause - GuidedSwingInstrumentPhraseCandidate.silentTopPause) < 0.000_001)

        for candidate in playableCandidates {
            #expect(candidate.events.map(\.assetName) == candidate.requiredAssetNames)
            #expect(candidate.events.map(\.offset) == GuidedSwingInstrumentPhraseCandidate.eventOffsets)
            #expect(candidate.requiredAssetNames.count == 4)
        }
    }

    @Test func eachPlayableLaneHasItsApprovedMusicalMap() {
        #expect(GuidedSwingInstrumentPhraseCandidate.feltPiano.musicalMap == "G3 → B3 → D4 → silence → G3/D4")
        #expect(GuidedSwingInstrumentPhraseCandidate.rosewoodMarimba.musicalMap == "A3 → C4 → E4 → silence → A3")
        #expect(GuidedSwingInstrumentPhraseCandidate.nylonGuitar.musicalMap == "E3 → G3 → B3 → silence → E3/B3")
        #expect(GuidedSwingInstrumentPhraseCandidate.luxuryUIChime.musicalMap == "C4 → E4 → G4 → silence → C4")
    }

    @Test func humanRhythmRemainsSpecOnlyAndUnplayable() {
        let candidate = GuidedSwingInstrumentPhraseCandidate.humanRhythm

        #expect(candidate.sourcingPriority == .specOnly)
        #expect(candidate.requiredAssetNames.isEmpty)
        #expect(candidate.events.isEmpty)
    }
}
#endif
