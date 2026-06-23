enum GarageGuidedSwingAudioProfileID: String, CaseIterable, Identifiable, Sendable {
    case premiumLiftHill

    var id: String { rawValue }
}

enum GarageGuidedSwingAudioLayerRole: String, CaseIterable, Sendable {
    case backswingPressureBuild
    case topSilence
    case downswingSilence
    case impactStrike
    case finishTail

    static let requiredSequence: [Self] = [
        .backswingPressureBuild,
        .topSilence,
        .downswingSilence,
        .impactStrike
    ]

    static let fullSequence: [Self] = requiredSequence + [.finishTail]

    var isOptional: Bool {
        self == .finishTail
    }
}

struct GarageGuidedSwingAudioLayer: Equatable, Sendable {
    let role: GarageGuidedSwingAudioLayerRole

    /// Directional 0...1 guidance for future mastering, not a raw output gain.
    let relativeIntensity: Double
    let energyGuidance: String
    let timingGuidance: String
}

struct GarageGuidedSwingAudioProfile: Identifiable, Equatable, Sendable {
    let id: GarageGuidedSwingAudioProfileID
    let displayName: String
    let shortDescription: String
    let intent: String
    let layers: [GarageGuidedSwingAudioLayer]

    /// Remains false until mastered audio passes physical iPhone speaker validation.
    let isFinalMasteredAudio: Bool
}

enum GarageGuidedSwingAudioProfileLibrary {
    static let premiumLiftHill = GarageGuidedSwingAudioProfile(
        id: .premiumLiftHill,
        displayName: "Premium Lift Hill",
        shortDescription: "Chain lift, silent release, real strike.",
        intent: "Use one serious sample-backed swing phrase: a high-altitude rollercoaster chain lift to the top, pure silence through release, and the supplied golf-swing WAV at impact.",
        layers: [
            GarageGuidedSwingAudioLayer(
                role: .backswingPressureBuild,
                relativeIntensity: 0.72,
                energyGuidance: "Slow, steady steel chain lift with rising pressure; mechanical, not musical.",
                timingGuidance: "Fill the full backswing and stop exactly at the top boundary."
            ),
            GarageGuidedSwingAudioLayer(
                role: .topSilence,
                relativeIntensity: 0,
                energyGuidance: "True silence after the chain stop. No exhale, breath, or top cue.",
                timingGuidance: "Begin immediately after the chain de-click fade."
            ),
            GarageGuidedSwingAudioLayer(
                role: .downswingSilence,
                relativeIntensity: 0,
                energyGuidance: "Exact digital silence. No zipper, sweep, click, breath, or pre-impact cue.",
                timingGuidance: "Hold silence until the impact boundary."
            ),
            GarageGuidedSwingAudioLayer(
                role: .impactStrike,
                relativeIntensity: 0.88,
                energyGuidance: "Supplied golf-swing WAV only; clean real strike without added crash or synthetic layer.",
                timingGuidance: "Align the internal strike transient with impact."
            ),
            GarageGuidedSwingAudioLayer(
                role: .finishTail,
                relativeIntensity: 0.28,
                energyGuidance: "Natural tail from the supplied impact recording only.",
                timingGuidance: "Let the approved tail finish inside the existing follow-through window."
            )
        ],
        isFinalMasteredAudio: false
    )

    static let all: [GarageGuidedSwingAudioProfile] = [
        premiumLiftHill
    ]

    static let legacyProfiles: [GarageGuidedSwingAudioProfile] = []

    static let defaultProfile = premiumLiftHill

    static func profile(for id: GarageGuidedSwingAudioProfileID) -> GarageGuidedSwingAudioProfile {
        all.first { $0.id == id } ?? defaultProfile
    }
}
