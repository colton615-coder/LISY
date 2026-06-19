import Testing
@testable import LIFE_IN_SYNC

struct GarageGuidedSwingAudioProfileTests {
    @Test func powerTourIsTheDefaultProfile() {
        #expect(GarageGuidedSwingAudioProfileLibrary.defaultProfile.id == .powerTour)
        #expect(GarageGuidedSwingAudioProfileLibrary.profile(for: .powerTour).displayName == "Power Tour")
    }

    @Test func profileIDsAreUniqueAndComplete() {
        let profiles = GarageGuidedSwingAudioProfileLibrary.all
        let ids = profiles.map(\.id)

        #expect(profiles.count == GarageGuidedSwingAudioProfileID.allCases.count)
        #expect(Set(ids).count == ids.count)
    }

    @Test func profilesContainTheRequiredLayerSequence() {
        for profile in GarageGuidedSwingAudioProfileLibrary.all {
            let roles = profile.layers.map(\.role)

            #expect(Array(roles.prefix(GarageGuidedSwingAudioLayerRole.requiredSequence.count)) == GarageGuidedSwingAudioLayerRole.requiredSequence)
            #expect(roles == GarageGuidedSwingAudioLayerRole.fullSequence)
            #expect(profile.layers.filter { $0.role.isOptional }.map(\.role) == [.finishTail])
        }
    }

    @Test func profilesContainUsableScaffoldMetadata() {
        for profile in GarageGuidedSwingAudioProfileLibrary.all {
            #expect(profile.displayName.isEmpty == false)
            #expect(profile.shortDescription.isEmpty == false)
            #expect(profile.intent.isEmpty == false)
            #expect(profile.layers.isEmpty == false)
            #expect(profile.layers.allSatisfy { (0...1).contains($0.relativeIntensity) })
            #expect(profile.isFinalMasteredAudio == false)
        }
    }
}
