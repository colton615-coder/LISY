import Testing
@testable import LIFE_IN_SYNC

struct GarageGuidedSwingAudioProfileTests {
    @Test func cleanAscendingRailIsTheDefaultAndMigratesLegacySelections() {
        #expect(GarageGuidedSwingAudioProfileLibrary.defaultProfile.id == .cleanAscendingRailWarm)
        #expect(GarageGuidedSwingAudioProfileLibrary.profile(for: .cleanAscendingRailWarm).displayName == "Clean Ascending Rail Warm")

        let legacyRawValues = [
            "cleanAscendingRail", "tourWhip", "heavySteel", "glassLine", "airCut",
            "digitalVector", "rangeWood", "powerTour", "heavyCoil", "whipLine"
        ]
        for rawValue in legacyRawValues {
            #expect(GarageGuidedSwingProfile.migrated(from: rawValue) == .cleanAscendingRailWarm)
        }
    }

    @Test func warmIsDefaultAndQAContainsExactlyTwoTunedVariants() {
        #expect(GarageGuidedSwingProfile.qaListeningOrder == [.cleanAscendingRailWarm, .cleanAscendingRailLow])
        #expect(GarageGuidedSwingProfile.qaListeningOrder.map(\.engineProfile) == [.cleanAscendingRailWarm, .cleanAscendingRailLow])
    }

    @Test func tunedRailsKeepSilentTopAndTail() {
        for profile in [TempoSoundIdentityProfile.cleanAscendingRailWarm, .cleanAscendingRailLow] {
            let plan = profile.eventPlan

            #expect(plan[.top].synthesisGain == 0)
            #expect(plan[.top].silenceWindow == 0...1)
            #expect(plan[.tail].synthesisGain == 0)
            #expect(plan[.build].synthesisGain > plan[.downswing].synthesisGain)
            #expect(plan[.impact].synthesisGain > 0)
        }
    }

    @Test func tunedRailsUseTheApprovedLowerRegisters() {
        #expect(TempoSoundIdentityProfile.cleanAscendingRailWarm.eventPlan[.build].pitch == .rising(from: 180, to: 360))
        #expect(TempoSoundIdentityProfile.cleanAscendingRailLow.eventPlan[.build].pitch == .rising(from: 140, to: 280))
        #expect(TempoSoundIdentityProfile.cleanAscendingRailWarm.eventPlan[.impact].pitch == .fixed(300))
        #expect(TempoSoundIdentityProfile.cleanAscendingRailLow.eventPlan[.impact].pitch == .fixed(230))
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

    @Test func profilesContainUsableScaffoldMetadata() {
        for profile in GarageGuidedSwingAudioProfileLibrary.all + GarageGuidedSwingAudioProfileLibrary.legacyProfiles {
            #expect(profile.displayName.isEmpty == false)
            #expect(profile.shortDescription.isEmpty == false)
            #expect(profile.intent.isEmpty == false)
            #expect(profile.layers.isEmpty == false)
            #expect(profile.layers.allSatisfy { (0...1).contains($0.relativeIntensity) })
            #expect(profile.isFinalMasteredAudio == false)
        }
    }

    @Test func cleanAscendingRailProducesBoundedDistinctAudioPhases() {
        let phases: [TempoSoundPhase] = [.build, .top, .downswing, .impact, .tail]
        let rendered = Dictionary(uniqueKeysWithValues: phases.map { phase in
            let samples = (0..<512).map { index in
                let progress = Double(index) / 511
                return GarageCleanAscendingRailSynthesis.sample(
                    phase: phase,
                    progress: progress,
                    primaryPhase: progress * .pi * 18,
                    bodyPhase: progress * .pi * 9,
                    isSpeaker: true
                )
            }
            return (phase, samples)
        })

        #expect(rendered[.build]!.contains { abs($0) > 0.01 })
        #expect(rendered[.impact]!.contains { abs($0) > 0.01 })
        #expect(rendered[.top]!.allSatisfy { $0 == 0 })
        #expect(rendered[.tail]!.allSatisfy { $0 == 0 })
        #expect(rendered.values.flatMap { $0 }.allSatisfy { abs($0) < 0.96 })

        let buildTailEnergy = rendered[.build]!.suffix(128).map { abs($0) }.reduce(0, +)
        let impactTailEnergy = rendered[.impact]!.suffix(128).map { abs($0) }.reduce(0, +)
        #expect(buildTailEnergy > impactTailEnergy * 2)
    }
}
