# Guided Swing Physical Mock Audio V2 Design

- Status: rejected and superseded by `CLEAN_ASCENDING_RAIL_GUIDED_SWING_AUDIO.md`
- Date: 2026-06-21
- Scope: standalone Guided Swing listening previews only
- App integration: none; retained only as historical context

> Listening review rejected the physical-material mock direction. Do not resume the 15-material set or use it as an implementation brief.

## Goal

Produce 15 genuinely different Guided Swing full-motion audio previews so the listener can identify preferred physical materials, load character, top marker, downswing release, and impact character before any further in-app tuning.

The V1 mock set failed because all previews shared one synthesizer architecture and differed primarily through parameter changes. V2 must use different dominant recorded-material foundations and different motion textures. Parameter variation inside one common sonic fingerprint is not sufficient.

## Product Constraints

- The result must feel serious, athletic, physical, and premium.
- Nothing may sound corny, weak, playful, overly electronic, computer-generated, sci-fi, arcade-like, meditative, or notification-like.
- Every preview must communicate a complete golf swing rather than isolated effects.
- Generated sound may connect and shape recorded material but may not provide the dominant identity.
- The mock set remains outside the app repository until the user selects preferred directions.
- No Tempo Builder UI, timing, persistence, haptic, Metronome, or session behavior changes are authorized by this design.

## Shared Coaching Sequence

Every preview uses the same coaching sequence so selection is based on sound identity rather than changed swing timing.

1. **Smooth load:** continuous rising pressure for approximately 1.5 seconds.
2. **Top marker:** one unmistakable physical cue identifying when the player's hands should reach the top. The marker must inherit the profile's material identity and must never become a beep.
3. **Held pause:** approximately 120–160 milliseconds of held tension and near-silence immediately after the top marker.
4. **Downswing whoosh:** a separate accelerating release that is clearly faster than the load.
5. **Impact strike:** a short, dry, physical strike immediately after the whoosh.
6. **Finish:** an extremely brief natural decay with no cinematic tail.

The top marker, held pause, downswing whoosh, and impact boundary must remain perceptually separate. The downswing may lead into impact, but the impact transient must not be masked by the whoosh.

## Fifteen Physical Identities

Each identity must use a unique primary impact source. Primary impact recordings may not be reused across identities.

1. Hickory load to hardwood strike.
2. Leather tension to hide snap.
3. Forged steel pressure to dry steel impact.
4. Heavy canvas compression to body punch.
5. Drum-skin tension to rim strike.
6. Stone drag to compact rock knock.
7. Rope torque to fiber whip.
8. Compressed-air pressure to physical air slam.
9. Carbon-shaft flex to composite crack.
10. Rubber resistance to dead athletic punch.
11. Ground grit to dense planted thump.
12. Boxing-leather rush to mitt impact.
13. Wood-and-metal load to club-like strike.
14. Mechanical spring tension to hard release.
15. Pure aerodynamic acceleration to ball-strike snap.

If a source recording makes an identity sound synthetic, decorative, or implausible, that source must be rejected rather than rescued with more processing.

## Source And Licensing Rules

- Dominant material layers must come from real recorded physical sources.
- Source material must be CC0, project-owned, or covered by another license explicitly approved before use.
- Every source component must be listed in a V2 source ledger with its original URL, author or library, license, and role in the preview.
- Preview production must not silently copy the existing generated Guided Swing identity files and relabel them as new physical families.
- Existing repository audio may be used only when its provenance is already documented and it supplies a legitimate physical recording rather than a generated identity layer.
- Source files and derived previews stay in the external V2 mock folder during selection.

## Construction Rules

- Real recorded material provides the dominant identity in every phase.
- No preview may use a sine-wave bed, digital pulse, sci-fi sweep, notification tone, or decorative beep as its foundation.
- Generated layers are limited to motion glue, filtering, envelope control, dynamics, speaker translation, and restrained connective whoosh support.
- All previews share phase boundaries, but internal texture and material behavior differ.
- The set spans premium-controlled through brutally physical aggression.
- Overall loudness is controlled for comparison, while crest factor and transient aggression remain meaningfully different.
- The top marker is a material event, not a generic marker reused across all 15 previews.
- Finish decay must end cleanly before any future rest interval.

## Output Package

Create a visible Desktop folder named `Guided Swing Physical Mock Audio V2` containing:

- 15 numbered mono WAV previews at 44.1 kHz and 16-bit resolution;
- one listening index using direct physical-material descriptions;
- one source and license ledger;
- no application code or bundled app assets.

Each WAV should be approximately three seconds long and should contain one complete swing without spoken count-in. Count-in is excluded so the user can compare the motion phrase rapidly; existing in-app count-in behavior remains unchanged.

## Verification

Automated checks must confirm:

- exactly 15 WAV previews exist;
- each file is mono, 44.1 kHz, 16-bit PCM;
- each file has the intended duration;
- no file clips;
- the held pause is measurably quieter than the adjacent top and downswing phases;
- every identity uses a unique primary impact source;
- every used source has a ledger entry.

Automated spectral or waveform differences are supporting evidence only. They do not prove that the previews feel distinct, physical, useful, or premium.

## Human Acceptance

The set is successful only if physical iPhone-speaker listening confirms all of the following:

- the smooth load is continuous and intentional;
- the top marker is immediately recognizable as the hands-at-the-top cue;
- the slight pause is perceptible;
- the downswing whoosh feels faster than the load;
- impact is short, dry, physical, and clearly separated;
- the 15 previews sound like different physical families rather than variations of one synthesizer;
- no preview sounds weak, corny, overly electronic, or computer-generated.

The user may select load, top marker, release, impact, and finish components from different previews. A winning in-app profile does not need to inherit every phase from one mock.

## Non-Goals

- Integrating any mock into `ElasticSlingshotAudioEngine`.
- Changing Guided Swing profile persistence or `garage.tempoBuilder.guidedSound` compatibility.
- Changing count-in, BPM boundary application, rest, haptics, or Metronome behavior.
- Adding packages or third-party runtime dependencies.
- Treating generated files as final mastered app assets before physical-device approval.
