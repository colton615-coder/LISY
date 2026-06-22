enum GarageGuidedSwingAudioProfileID: String, CaseIterable, Identifiable, Sendable {
    case cleanAscendingRail
    case cleanAscendingRailWarm
    case cleanAscendingRailLow

    var id: String { rawValue }
}

enum GarageGuidedSwingAudioLayerRole: String, CaseIterable, Sendable {
    case addressCue
    case backswingPressureBuild
    case topCheckpoint
    case downswingRelease
    case impactStrike
    case finishTail

    static let requiredSequence: [Self] = [
        .addressCue,
        .backswingPressureBuild,
        .topCheckpoint,
        .downswingRelease,
        .impactStrike
    ]

    static let fullSequence: [Self] = requiredSequence + [.finishTail]

    var isOptional: Bool {
        self == .finishTail
    }
}

struct GarageGuidedSwingAudioLayer: Equatable, Sendable {
    let role: GarageGuidedSwingAudioLayerRole

    /// Directional 0...1 guidance for future synthesis and mastering, not a raw output gain.
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

/// Directional metadata only. Future renderers must preserve headroom, build perceived loudness
/// through mastering and dynamics control rather than clipping, and keep top, release, and impact distinct.
enum GarageGuidedSwingAudioProfileLibrary {
    static let cleanAscendingRail = GarageGuidedSwingAudioProfile(
        id: .cleanAscendingRail,
        displayName: "Clean Ascending Rail Reference",
        shortDescription: "Internal compatibility reference.",
        intent: "Preserve the original saved value while routing listening toward the warmer approved register.",
        layers: [
            GarageGuidedSwingAudioLayer(
                role: .addressCue,
                relativeIntensity: 0.12,
                energyGuidance: "Barely present tonal onset.",
                timingGuidance: "Blend into the rail without a separate click."
            ),
            GarageGuidedSwingAudioLayer(
                role: .backswingPressureBuild,
                relativeIntensity: 0.72,
                energyGuidance: "Legacy tonal rise retained for compatibility only.",
                timingGuidance: "Rise smoothly and continuously through the full backswing."
            ),
            GarageGuidedSwingAudioLayer(
                role: .topCheckpoint,
                relativeIntensity: 0,
                energyGuidance: "True silence.",
                timingGuidance: "Leave the top hold empty so the transition is learned through space."
            ),
            GarageGuidedSwingAudioLayer(
                role: .downswingRelease,
                relativeIntensity: 0.48,
                energyGuidance: "Short, clean tonal lift from the same harmonic family.",
                timingGuidance: "Enter after the silent top hold and move directly toward impact."
            ),
            GarageGuidedSwingAudioLayer(
                role: .impactStrike,
                relativeIntensity: 0.64,
                energyGuidance: "Legacy tonal resolution retained for compatibility only.",
                timingGuidance: "Resolve at impact with a smooth attack and fast release."
            ),
            GarageGuidedSwingAudioLayer(
                role: .finishTail,
                relativeIntensity: 0,
                energyGuidance: "Silent.",
                timingGuidance: "Do not add a cinematic or material tail."
            )
        ],
        isFinalMasteredAudio: false
    )

    static let cleanAscendingRailWarm = tunedRailProfile(
        id: .cleanAscendingRailWarm,
        displayName: "Clean Ascending Rail Warm",
        shortDescription: "Rounded warm rise, quiet top, muted confirmation.",
        intent: "Preferred tonal tempo guide with reduced upper-frequency energy for repeated iPhone-speaker practice."
    )

    static let cleanAscendingRailLow = tunedRailProfile(
        id: .cleanAscendingRailLow,
        displayName: "Clean Ascending Rail Low",
        shortDescription: "Lower rounded rise, quiet top, soft low confirmation.",
        intent: "QA alternative for players who prefer a deeper register with minimal tonal fatigue."
    )

    static let all: [GarageGuidedSwingAudioProfile] = [
        cleanAscendingRailWarm,
        cleanAscendingRailLow
    ]

    static let legacyProfiles: [GarageGuidedSwingAudioProfile] = [cleanAscendingRail]

    static let defaultProfile = cleanAscendingRailWarm

    static func profile(for id: GarageGuidedSwingAudioProfileID) -> GarageGuidedSwingAudioProfile {
        (all + legacyProfiles).first { $0.id == id } ?? defaultProfile
    }

    private static func tunedRailProfile(
        id: GarageGuidedSwingAudioProfileID,
        displayName: String,
        shortDescription: String,
        intent: String
    ) -> GarageGuidedSwingAudioProfile {
        GarageGuidedSwingAudioProfile(
            id: id,
            displayName: displayName,
            shortDescription: shortDescription,
            intent: intent,
            layers: [
                GarageGuidedSwingAudioLayer(
                    role: .addressCue,
                    relativeIntensity: 0.10,
                    energyGuidance: "Soft rounded onset with no click or transient marker.",
                    timingGuidance: "Blend directly into the rail."
                ),
                GarageGuidedSwingAudioLayer(
                    role: .backswingPressureBuild,
                    relativeIntensity: 0.68,
                    energyGuidance: "Soft triangle-led body with quiet sine support and a restrained sub-body.",
                    timingGuidance: "Rise smoothly through the unchanged backswing duration."
                ),
                GarageGuidedSwingAudioLayer(
                    role: .topCheckpoint,
                    relativeIntensity: 0,
                    energyGuidance: "True silence.",
                    timingGuidance: "Preserve the existing empty top hold."
                ),
                GarageGuidedSwingAudioLayer(
                    role: .downswingRelease,
                    relativeIntensity: 0.40,
                    energyGuidance: "Compact rounded cue from the same low-harmonic family.",
                    timingGuidance: "Enter after silence and move directly toward impact."
                ),
                GarageGuidedSwingAudioLayer(
                    role: .impactStrike,
                    relativeIntensity: 0.46,
                    energyGuidance: "Muted warm confirmation without brightness or object-impact character.",
                    timingGuidance: "Short smooth attack with a fast rounded decay."
                ),
                GarageGuidedSwingAudioLayer(
                    role: .finishTail,
                    relativeIntensity: 0,
                    energyGuidance: "Silent.",
                    timingGuidance: "Do not add a tail."
                )
            ],
            isFinalMasteredAudio: false
        )
    }
}
