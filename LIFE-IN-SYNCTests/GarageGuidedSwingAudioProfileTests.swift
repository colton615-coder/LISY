import Testing
@testable import LIFE_IN_SYNC

struct GarageGuidedSwingAudioProfileTests {
    @Test func cleanAscendingRailIsTheDefaultAndMigratesLegacySelections() {
        #expect(GarageGuidedSwingAudioProfileLibrary.defaultProfile.id == .cleanAscendingRail)
        #expect(GarageGuidedSwingAudioProfileLibrary.profile(for: .cleanAscendingRail).displayName == "Clean Ascending Rail")

        for legacyProfile in GarageGuidedSwingProfile.legacyProfiles {
            #expect(GarageGuidedSwingProfile.migrated(from: legacyProfile.rawValue) == .cleanAscendingRail)
        }
    }

    @Test func onlyCleanAscendingRailIsAppFacing() {
        #expect(GarageGuidedSwingProfile.listeningOrder == [.cleanAscendingRail])
        #expect(GarageGuidedSwingProfile.listeningOrder.map(\.engineProfile) == [.cleanAscendingRail])
        #expect(GarageGuidedSwingProfile.legacyProfiles.contains(.tourWhip))
    }

    @Test func cleanAscendingRailHasTrueSilentTopAndTail() {
        let plan = TempoSoundIdentityProfile.cleanAscendingRail.eventPlan

        #expect(plan[.top].synthesisGain == 0)
        #expect(plan[.top].silenceWindow == 0...1)
        #expect(plan[.tail].synthesisGain == 0)
        #expect(plan[.build].synthesisGain > plan[.downswing].synthesisGain)
        #expect(plan[.impact].synthesisGain > 0)
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
                    harmonicPhase: progress * .pi * 36,
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
