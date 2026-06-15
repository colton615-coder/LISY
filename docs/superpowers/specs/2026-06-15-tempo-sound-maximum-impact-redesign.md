# Tempo Sound Maximum-Impact Redesign

## Status

Approved design for rebuilding all six Guided Swing sound identities after
real-device listening found them too weak and too similar.

This is a design contract only. No implementation or audio asset replacement is
included in this design pass.

## Verdict

The current issue is not final mastering. The six identities are being weakened
by similar dynamic contours, normalized asset stretching, conservative source
material, and a shared limiting path that reduces transient contrast.

The solution is a full Guided Swing identity-asset rebuild with exaggerated
physical materials and maximum-impact dynamics. Product behavior, shared swing
timing, and the existing six-profile system remain intact.

## Goal

Make every Guided Swing identity:

- substantially stronger
- immediately recognizable
- physically forceful
- clearly different from the other five
- unmistakable within one swing

Weakness and similarity are failures. Listening fatigue is acceptable for this
pass.

## Locked Direction

- Intensity: maximum impact
- Material direction: exaggerated physical materials
- Scope: rebuild all six identity asset sets
- Sequence timing: identical shared build, top, downswing, impact, and tail
  timing across all identities
- Asset ownership: original local LIFE-IN-SYNC WAV assets only
- UI scope: no Control Room or Tempo Builder redesign

## Protected Product Behavior

Do not change:

- live route or navigation
- `garage.tempoBuilder.guidedSound`
- separate Guided Swing and Metronome BPM storage
- saved-versus-applied BPM behavior
- tempo ratio behavior
- count-in placement
- Start, Stop, Resume, and rest behavior
- Swing Capture entry
- Control Room selector order
- Metronome audio or sound library

The live implementation seam remains:

- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
- `LIFE-IN-SYNC/Garage/Metronome_Audio/`

`GarageTempoWizard.swift` remains outside the live route.

## Architecture

Preserve the existing identity-owned five-phase model:

1. build
2. top
3. downswing
4. impact
5. tail

Preserve shared swing-phase timing so all identities remain directly comparable
at the same BPM and ratio.

Rebuild every identity's five phase assets, for 30 WAV files total. Preserve all
29 existing filenames and add `tour_whip_loaded_silence.wav` for Tour Whip's
intentional silent top. Profile selection and persistence do not require
migration.

Each identity retains its dedicated synthesis-support path. Synthesis remains
secondary and must not be the primary source of identity. The rebuilt assets
must carry the physical material, force, and separation.

## Transient-Preserving Playback

The current asset renderer selects samples using normalized phase progress. This
forces each entire asset across the phase duration and can smear short top cues
and impacts.

Change asset playback by phase:

- Build: continue mapping across the shared build duration.
- Downswing: continue mapping across the shared downswing duration.
- Tail: continue mapping across the shared tail duration.
- Top marker: play the asset at its native sample progression from phase start,
  then allow silence for the remainder of the shared top phase.
- Impact: play the asset at its native sample progression from impact start,
  then allow silence for the remainder of the shared impact phase.

This preserves identical sequence timing while protecting the attack shape of
hard cues.

Tour Whip remains intentionally silent during the top phase.
`tour_whip_loaded_silence.wav` documents and completes that phase asset while
the event plan's full silence window guarantees no audible playback.

The implementation should extend the existing phase plan or asset-sampling
function with an explicit playback behavior. Do not create a second audio
engine or separate scheduler.

## Dynamic Processing

Maximum impact requires more contrast before limiting.

Required changes:

- Give impacts the fastest attacks and strongest phase gains.
- Keep build and downswing energy below impact energy.
- Keep tails short enough that the impact remains dominant.
- Reduce premature soft limiting that rounds every identity into a similar
  shape.
- Preserve a final safety ceiling to prevent digital clipping.
- Keep synthesis gains secondary to the physical asset signal.

Do not solve weakness by applying one global gain increase. Each identity and
phase must be balanced according to its material.

## Six Identity Definitions

### Tour Whip

Material language: exaggerated leather tension and aerodynamic whip force.

| Phase | Required behavior |
| --- | --- |
| Build | Tightening leather tension with obvious stored force |
| Top | Complete loaded silence |
| Downswing | Violent accelerating aerodynamic crack |
| Impact | Sharp, hard leather impact |
| Tail | Short snapped leather tail |

Tour Whip must be the tightest and fastest identity. It must not become a broad
air effect.

Existing filenames:

- `tour_whip_tension.wav`
- `tour_whip_loaded_silence.wav`
- `tour_whip_air.wav`
- `tour_whip_leather_crack.wav`
- `tour_whip_snap_tail.wav`

### Heavy Steel

Material language: industrial pressure, falling forged mass, and anvil-grade
impact.

| Phase | Required behavior |
| --- | --- |
| Build | Industrial low pressure with increasing mass |
| Top | Decisive forged locking slam |
| Downswing | Falling metal mass with clear acceleration |
| Impact | Anvil-grade steel strike |
| Tail | Short dense steel resonance |

Heavy Steel must be the heaviest and lowest identity. It must not become a long
cinematic rumble.

Existing filenames:

- `heavy_steel_pressure.wav`
- `heavy_steel_lock.wav`
- `heavy_steel_drop.wav`
- `heavy_steel_forged_strike.wav`
- `heavy_steel_resonance.wav`

### Glass Line

Material language: stressed crystal and violent physical fracture.

| Phase | Required behavior |
| --- | --- |
| Build | Rising crystalline stress under tension |
| Top | Suspended hard glass lock |
| Downswing | Violent descending fracture dive |
| Impact | Breaking-glass strike with a hard center |
| Tail | Short scattered shard tail |

Glass Line must feel physical and dangerous, not elegant, delicate, or
electronic. High-frequency force must remain controlled enough to avoid digital
harshness.

Existing filenames:

- `glass_line_crystal_rise.wav`
- `glass_line_suspension.wav`
- `glass_line_pitch_dive.wav`
- `glass_line_ping.wav`
- `glass_line_shimmer_tail.wav`

### Air Cut

Material language: compressed pressure, vacuum drop, and explosive aerodynamic
release.

| Phase | Required behavior |
| --- | --- |
| Build | Compressed pressure building toward release |
| Top | Decisive vacuum-drop cue |
| Downswing | High-speed aerodynamic rush |
| Impact | Explosive compact air burst |
| Tail | Immediate pressure release |

Air Cut must be broader than Tour Whip but still hit hard. It must not become a
quiet noise wash.

Existing filenames:

- `air_cut_filtered_wind.wav`
- `air_cut_pressure_drop.wav`
- `air_cut_whoosh.wav`
- `air_cut_air_burst.wav`
- `air_cut_tail.wav`

### Digital Vector

Material language: escalating machine sequence and surgical digital strike.

| Phase | Required behavior |
| --- | --- |
| Build | Escalating machine sequence with clear steps |
| Top | Hard gated lock |
| Downswing | Accelerating data strike |
| Impact | Surgical maximum-force digital transient |
| Tail | Clipped shutdown tail |

Digital Vector must remain the only explicitly electronic identity. It must be
harder and more abrupt than the physical identities, not merely brighter.

Existing filenames:

- `digital_vector_steps.wav`
- `digital_vector_lock.wav`
- `digital_vector_pulse.wav`
- `digital_vector_transient.wav`
- `digital_vector_tail.wav`

### Range Wood

Material language: flexing hardwood, club speed, and a heavy hardwood strike.

| Phase | Required behavior |
| --- | --- |
| Build | Flexing hardwood with rising stored energy |
| Top | Dense wooden lock |
| Downswing | Dry club-speed sweep |
| Impact | Heavy hardwood strike |
| Tail | Short cabinet-body resonance |

Range Wood must be warmer and drier than Heavy Steel, but it must not feel
light, hollow, or toy-like.

Existing filenames:

- `range_wood_resonance.wav`
- `range_wood_muted_knock.wav`
- `range_wood_dry_sweep.wav`
- `range_wood_hardwood_strike.wav`
- `range_wood_tail.wav`

## Asset Production

Replace all 29 existing Guided Swing WAV files and add
`tour_whip_loaded_silence.wav`. The expected total is 30 physical files across
30 phase definitions.

Asset rules:

- original locally generated project-owned audio only
- preserve current filenames
- add only `tour_whip_loaded_silence.wav`
- mono, 44.1 kHz, 16-bit PCM WAV
- impact assets use the hardest attack and highest peak
- top and impact assets stay short and transient-focused
- builds communicate stored force
- downswings communicate acceleration
- tails remain short and material-specific
- no digital clipping in asset files

The source manifest and license ledger must be updated to describe the rebuilt
maximum-impact assets. Do not falsely describe the work as final mastering.

## Loudness Direction

This pass intentionally targets maximum impact.

Required hierarchy:

1. Impact
2. Downswing
3. Top marker
4. Build
5. Tail

Tour Whip's silent top is the exception.

Perceived loudness must be aggressively raised compared with the current assets,
but identity distinction is more important than numerical equality. The
implementation must avoid a global normalization step that makes all identities
equally dense.

## Implementation Scope

Expected changes:

- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
- existing Guided Swing WAV files under
  `LIFE-IN-SYNC/Garage/Metronome_Audio/`
- `LIFE-IN-SYNC/Garage/Metronome_Audio/SOURCE_MANIFEST.json`
- `LIFE-IN-SYNC/Garage/Metronome_Audio/LICENSES.md`
- narrow Garage Tempo tests if required for playback behavior

Do not change `HorizonVaultDialView.swift` unless compile-required. The current
six-profile Control Room selection surface is already correct.

## Verification

Follow the strict repository verification budget.

Static verification:

- focused Swift parse for changed Swift files
- `git diff --check`
- validate manifest JSON
- validate every Guided Swing WAV as mono, 44.1 kHz, 16-bit PCM
- confirm no asset-level clipping
- confirm every event-plan asset maps to a real WAV
- confirm no Metronome asset changed
- confirm all six profile names and selector order remain unchanged

Do not run simulators, screenshots, Computer Use, or visual QA unless explicitly
requested.

Runtime listening acceptance:

- listen at 45 BPM
- listen at 60 BPM
- listen at 75 BPM
- test iPhone speaker
- test headphones
- rapidly switch between all six identities

## Acceptance Criteria

The redesign succeeds only when:

1. Every identity sounds substantially stronger than the current version.
2. Every identity is immediately distinguishable from the other five.
3. Every impact is hard, unmistakable, and material-specific.
4. Top cues are decisive, except Tour Whip's intentional silence.
5. Shared sequence timing remains identical across all six identities.
6. Top and impact transients are no longer smeared across phase duration.
7. No identity sounds like the same recipe with a different filter.
8. No new persistence, routing, UI, or session behavior is introduced.
9. All replacement assets remain local and project-owned.
10. Final mastering is not claimed.

## Explicit Non-Goals

- restrained or low-fatigue listening
- subtle identity differences
- cinematic long tails
- different sequence timing per identity
- UI redesign
- new sound identities
- Metronome changes
- new persistence or migrations
- final mastering

## Next Step After Implementation

Stop development after the maximum-impact rebuild and perform the required
real-device listening matrix. Any later work must be driven by specific
identity-level feedback, not a global request to make everything louder.
