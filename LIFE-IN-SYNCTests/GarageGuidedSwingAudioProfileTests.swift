import Testing
@testable import LIFE_IN_SYNC

struct GarageGuidedSwingAudioProfileTests {
    @Test func premiumLiftHillIsTheDefaultAndMigratesLegacySelections() {
        #expect(GarageGuidedSwingAudioProfileLibrary.defaultProfile.id == .premiumLiftHill)
        #expect(GarageGuidedSwingAudioProfileLibrary.profile(for: .premiumLiftHill).displayName == "Premium Lift Hill")

        let legacyRawValues = [
            "cleanAscendingRail", "cleanAscendingRailWarm", "cleanAscendingRailLow",
            "tourWhip", "heavySteel", "glassLine", "airCut", "digitalVector",
            "rangeWood", "powerTour", "heavyCoil", "whipLine"
        ]
        for rawValue in legacyRawValues {
            #expect(GarageGuidedSwingProfile.migrated(from: rawValue) == .premiumLiftHill)
        }
    }

    @Test func qaContainsOnlyPremiumLiftHill() {
        #expect(GarageGuidedSwingProfile.qaListeningOrder == [.premiumLiftHill])
        #expect(GarageGuidedSwingProfile.qaListeningOrder.map(\.engineProfile) == [.premiumLiftHill])
    }

    @Test func premiumLiftHillUsesTwoAssetsAndNoGeneratedFallback() {
        let plan = TempoSoundIdentityProfile.premiumLiftHill.eventPlan

        #expect(plan[.build].assetName == "backswing_premium_lift_hill")
        #expect(plan[.impact].assetName == "impact_golf_swing")
        #expect(plan[.build].synthesisGain == 0)
        #expect(plan[.top].synthesisGain == 0)
        #expect(plan[.downswing].synthesisGain == 0)
        #expect(plan[.impact].synthesisGain == 0)
        #expect(plan[.tail].synthesisGain == 0)
        #expect(plan[.top].silenceWindow == 0...1)
        #expect(plan[.downswing].silenceWindow == 0...1)
        #expect(TempoSoundIdentityProfile.requiredAssetNames == [
            "backswing_premium_lift_hill",
            "impact_golf_swing"
        ])
    }

    @Test func profileIDsAreUniqueAndComplete() {
        let profiles = GarageGuidedSwingAudioProfileLibrary.all + GarageGuidedSwingAudioProfileLibrary.legacyProfiles
        let ids = profiles.map(\.id)

        #expect(profiles.count == GarageGuidedSwingAudioProfileID.allCases.count)
        #expect(Set(ids).count == ids.count)
    }

    @Test func profilesContainTheRequiredLayerSequence() {
        for profile in GarageGuidedSwingAudioProfileLibrary.all + GarageGuidedSwingAudioProfileLibrary.legacyProfiles {
            let roles = profile.layers.map(\.role)

            #expect(Array(roles.prefix(GarageGuidedSwingAudioLayerRole.requiredSequence.count)) == GarageGuidedSwingAudioLayerRole.requiredSequence)
            #expect(roles == GarageGuidedSwingAudioLayerRole.fullSequence)
            #expect(profile.layers.filter { $0.role.isOptional }.map(\.role) == [.finishTail])
        }
    }

    @Test func profilesContainUsableMetadata() {
        for profile in GarageGuidedSwingAudioProfileLibrary.all + GarageGuidedSwingAudioProfileLibrary.legacyProfiles {
            #expect(profile.displayName.isEmpty == false)
            #expect(profile.shortDescription.isEmpty == false)
            #expect(profile.intent.isEmpty == false)
            #expect(profile.layers.isEmpty == false)
            #expect(profile.layers.allSatisfy { (0...1).contains($0.relativeIntensity) })
            #expect(profile.isFinalMasteredAudio == false)
        }
    }
}
