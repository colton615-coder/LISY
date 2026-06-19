enum GarageGuidedSwingAudioProfileID: String, CaseIterable, Identifiable, Sendable {
    case powerTour
    case heavyCoil
    case whipLine

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
    static let powerTour = GarageGuidedSwingAudioProfile(
        id: .powerTour,
        displayName: "Power Tour",
        shortDescription: "Balanced, powerful, and polished.",
        intent: "Default premium training baseline with a strong pressure build and satisfying physical impact.",
        layers: [
            GarageGuidedSwingAudioLayer(
                role: .addressCue,
                relativeIntensity: 0.34,
                energyGuidance: "Clear and composed.",
                timingGuidance: "Short readiness marker before motion begins."
            ),
            GarageGuidedSwingAudioLayer(
                role: .backswingPressureBuild,
                relativeIntensity: 0.78,
                energyGuidance: "Controlled pressure with broad, premium weight.",
                timingGuidance: "Rise continuously through the full backswing."
            ),
            GarageGuidedSwingAudioLayer(
                role: .topCheckpoint,
                relativeIntensity: 0.62,
                energyGuidance: "Compact lock with confident definition.",
                timingGuidance: "Mark the top cleanly without extending the pause."
            ),
            GarageGuidedSwingAudioLayer(
                role: .downswingRelease,
                relativeIntensity: 0.86,
                energyGuidance: "Fast athletic release with controlled width.",
                timingGuidance: "Accelerate faster than the backswing and clear space for impact."
            ),
            GarageGuidedSwingAudioLayer(
                role: .impactStrike,
                relativeIntensity: 1.0,
                energyGuidance: "Physical, premium, and decisive.",
                timingGuidance: "Short, dry transient at the impact boundary."
            ),
            GarageGuidedSwingAudioLayer(
                role: .finishTail,
                relativeIntensity: 0.26,
                energyGuidance: "Brief polished release of energy.",
                timingGuidance: "Decay quickly without masking impact or entering rest."
            )
        ],
        isFinalMasteredAudio: false
    )

    static let heavyCoil = GarageGuidedSwingAudioProfile(
        id: .heavyCoil,
        displayName: "Heavy Coil",
        shortDescription: "Lower, heavier, and more grounded.",
        intent: "Reinforce pressure, load, and body coil for players who rush the backswing.",
        layers: [
            GarageGuidedSwingAudioLayer(
                role: .addressCue,
                relativeIntensity: 0.40,
                energyGuidance: "Low, stable, and grounded.",
                timingGuidance: "Short readiness marker before motion begins."
            ),
            GarageGuidedSwingAudioLayer(
                role: .backswingPressureBuild,
                relativeIntensity: 0.92,
                energyGuidance: "Dense load with increasing body pressure.",
                timingGuidance: "Use the full backswing duration to reinforce patience and coil."
            ),
            GarageGuidedSwingAudioLayer(
                role: .topCheckpoint,
                relativeIntensity: 0.74,
                energyGuidance: "Firm loaded lock without metallic ring.",
                timingGuidance: "Hold definition at the checkpoint without creating a muddy stop."
            ),
            GarageGuidedSwingAudioLayer(
                role: .downswingRelease,
                relativeIntensity: 0.80,
                energyGuidance: "Heavy energy turning into decisive speed.",
                timingGuidance: "Move faster than the load and separate clearly from the top marker."
            ),
            GarageGuidedSwingAudioLayer(
                role: .impactStrike,
                relativeIntensity: 1.0,
                energyGuidance: "Deep, dry, and physically grounded.",
                timingGuidance: "Short transient with enough upper definition for iPhone speakers."
            ),
            GarageGuidedSwingAudioLayer(
                role: .finishTail,
                relativeIntensity: 0.30,
                energyGuidance: "Compact low-weight finish.",
                timingGuidance: "Decay quickly and keep the rest interval clean."
            )
        ],
        isFinalMasteredAudio: false
    )

    static let whipLine = GarageGuidedSwingAudioProfile(
        id: .whipLine,
        displayName: "Whip Line",
        shortDescription: "Sharper, faster, and more athletic.",
        intent: "Emphasize sequence, speed, release, and snap without drifting into sci-fi effects.",
        layers: [
            GarageGuidedSwingAudioLayer(
                role: .addressCue,
                relativeIntensity: 0.30,
                energyGuidance: "Tight and alert.",
                timingGuidance: "Very short readiness marker before motion begins."
            ),
            GarageGuidedSwingAudioLayer(
                role: .backswingPressureBuild,
                relativeIntensity: 0.70,
                energyGuidance: "Lean tension with clear forward intent.",
                timingGuidance: "Build smoothly without rushing the backswing schedule."
            ),
            GarageGuidedSwingAudioLayer(
                role: .topCheckpoint,
                relativeIntensity: 0.58,
                energyGuidance: "Tight sequence lock with no decorative beep.",
                timingGuidance: "Mark the transition briefly and hand off immediately to release."
            ),
            GarageGuidedSwingAudioLayer(
                role: .downswingRelease,
                relativeIntensity: 0.96,
                energyGuidance: "Sharp acceleration, width, and athletic snap.",
                timingGuidance: "Move decisively faster than the backswing and drive into impact."
            ),
            GarageGuidedSwingAudioLayer(
                role: .impactStrike,
                relativeIntensity: 1.0,
                energyGuidance: "Fast, dry, and satisfying without brittle harshness.",
                timingGuidance: "Short transient at the impact boundary with no overlap blob."
            ),
            GarageGuidedSwingAudioLayer(
                role: .finishTail,
                relativeIntensity: 0.22,
                energyGuidance: "Quick aerodynamic finish.",
                timingGuidance: "End rapidly before the reset interval."
            )
        ],
        isFinalMasteredAudio: false
    )

    static let all: [GarageGuidedSwingAudioProfile] = [
        powerTour,
        heavyCoil,
        whipLine
    ]

    static let defaultProfile = powerTour

    static func profile(for id: GarageGuidedSwingAudioProfileID) -> GarageGuidedSwingAudioProfile {
        all.first { $0.id == id } ?? defaultProfile
    }
}
