# Tempo Sound Identity Pass 2 Design

## Status

Approved design for completing the Guided Swing six-identity sound system.

This document defines the implementation contract only. No audio implementation,
asset generation, or product behavior changes are included in this design pass.

## Goal

Add three distinct Guided Swing sound identities:

1. Glass Line
2. Air Cut
3. Range Wood

The pass completes the six-identity system while preserving the approved
baseline identities:

1. Tour Whip
2. Heavy Steel
3. Digital Vector

Final mastering is explicitly out of scope. This pass performs rough
identity-level loudness balancing only. Final loudness normalization must wait
for listening approval on an iPhone speaker and headphones.

## Product Contract

- Keep Tempo Builder local-first and offline-first.
- Use bundled local WAV assets only.
- Do not add remote audio, streaming, accounts, network dependencies, or
  third-party packages.
- Keep the existing Guided Swing count-in, tempo, ratio, Start, Stop, Resume,
  rest, and pending-BPM behavior intact.
- Preserve separate Guided Swing and Metronome BPM memory.
- Preserve the shared top-bar Control Room entry and its mode-specific content.
- Keep the player-facing Control Room compact and practical.
- Do not redesign unrelated Garage screens.

## Live Ownership

The live route is:

`GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView()`

The routed Tempo Builder screen and Control Room live in:

- `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`

The active Guided Swing audio identity architecture lives in:

- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`

Local audio assets and source records live in:

- `LIFE-IN-SYNC/Garage/Metronome_Audio/`
- `LIFE-IN-SYNC/Garage/Metronome_Audio/SOURCE_MANIFEST.json`
- `LIFE-IN-SYNC/Garage/Metronome_Audio/LICENSES.md`

`GarageTempoWizard.swift` is not the live Tempo Builder route and must not be
used as the implementation target.

## Chosen Approach

Use asset-led hybrid identities inside the existing
`TempoSoundIdentityProfile` architecture.

Each new identity owns:

- a dedicated event plan
- one phase plan for build, top, downswing, impact, and tail
- five dedicated locally generated WAV assets
- identity-specific synthesis support at low gain
- identity-specific pitch behavior
- identity-specific envelope and silence behavior
- identity-level output gain

Existing shared playback infrastructure remains shared:

- asset loading
- phase scheduling
- envelope application
- soft limiting
- one-cycle preview playback
- continuous Guided Swing playback

Shared creative recipes are not allowed. Each new identity must have a separate
generated-sample function or equivalent identity-owned synthesis path.

## Alternatives Rejected

### Fully Asset-Driven

Rejected because static assets alone may not preserve responsive pitch movement
across the supported BPM range.

### Synthesis-Led

Rejected because it creates the highest risk of the identities sounding like
variations of one procedural recipe rather than distinct physical sound
languages.

## Identity Definitions

### Glass Line

Intent: clean, bright, crystalline, and precise without sounding electronic.

| Phase | Behavior |
| --- | --- |
| Build | Polished crystalline rise with a smooth high-frequency lift |
| Top | Held crystalline resonance with a controlled suspension |
| Downswing | Smooth, elegant pitch dive into impact |
| Impact | Precise physical glass ping with controlled high-frequency energy |
| Tail | Short shimmering decay |

Implementation rules:

- The top cue is an audible held resonance, not silence or a frozen sparkle bed.
- The downswing must descend smoothly after the held top.
- Avoid stepped, gated, or pulse-like behavior associated with Digital Vector.
- Protect iPhone speakers from harsh high-frequency spikes.
- Start rough balancing below Tour Whip's output level.

Planned local assets:

- `glass_line_crystal_rise.wav`
- `glass_line_suspension.wav`
- `glass_line_pitch_dive.wav`
- `glass_line_ping.wav`
- `glass_line_shimmer_tail.wav`

### Air Cut

Intent: wide, fast, aerodynamic, breathable, and clean.

| Phase | Behavior |
| --- | --- |
| Build | Broad filtered wind with a soft entry and widening body |
| Top | Near-silent pressure drop with only faint residual air texture |
| Downswing | Accelerating clean whoosh |
| Impact | Compact air burst |
| Tail | Rapidly disappearing airflow |

Implementation rules:

- The top cue must feel like pressure withdrawing, not a loud marker.
- The top is not complete digital silence; a faint residual texture remains.
- Air Cut must be broader and cleaner than Tour Whip.
- Avoid a tight tactile crack or Tour Whip-style snap.
- Avoid plain white-noise fatigue by relying on shaped local textures and
  controlled synthesis support.

Planned local assets:

- `air_cut_filtered_wind.wav`
- `air_cut_pressure_drop.wav`
- `air_cut_whoosh.wav`
- `air_cut_air_burst.wav`
- `air_cut_tail.wav`

### Range Wood

Intent: warm, grounded, natural practice-range physicality with a substantial
hardwood club-strike character.

| Phase | Behavior |
| --- | --- |
| Build | Warm hardwood resonance with a natural body |
| Top | Muted dense knock |
| Downswing | Dry physical sweep |
| Impact | Substantial hardwood club strike |
| Tail | Short wooden body resonance |

Implementation rules:

- Range Wood is denser than a light ash practice stick.
- It must remain warmer, lighter, and more human than Heavy Steel.
- Pitch movement stays subtle and natural.
- Avoid cartoon woodblock tones and toy-metronome character.
- The impact can carry weight, but the tail must remain short and dry.

Planned local assets:

- `range_wood_resonance.wav`
- `range_wood_muted_knock.wav`
- `range_wood_dry_sweep.wav`
- `range_wood_hardwood_strike.wav`
- `range_wood_tail.wav`

## Approved Baseline Protection

The following event plans and generated-sample behavior are locked:

- Tour Whip
- Heavy Steel
- Digital Vector

They may only change when required for:

- enum expansion
- exhaustive switch compatibility
- selector integration
- safe rough loudness comparison

Any baseline change must be explicitly reported. Do not retune or remaster the
baseline identities during this pass.

## Data and Audio Flow

1. The user opens Guided Swing's shared Control Room.
2. The existing Guided Swing selector displays all six identities.
3. Tapping a row saves the selected `GarageGuidedSwingProfile` raw value through
   the existing `garage.tempoBuilder.guidedSound` AppStorage key.
4. The tap immediately starts the existing one-cycle preview using the selected
   identity's engine profile.
5. `TempoSoundAssetLibrary` discovers every asset name referenced by all event
   plans and loads the bundled WAV files.
6. The existing renderer schedules build, top, downswing, impact, and tail using
   the current tempo and ratio timing.
7. The selected identity's dedicated generated-sample function supports its
   assets without replacing their physical character.
8. The existing limiter protects the final output while identity and phase gains
   provide rough balance.

Missing asset behavior remains non-crashing: the loader logs missing identity
assets in DEBUG and the renderer continues with available synthesis support.
Missing assets are still a QA failure and must not be accepted as complete.

## Control Room Design

Keep the current Guided Swing Control Room structure and
`GarageTempoSoundRow`. Do not introduce a new card system, horizontal carousel,
or separate preview screen.

Display one Guided Swing group with this listening order:

1. Tour Whip
2. Heavy Steel
3. Glass Line
4. Air Cut
5. Digital Vector
6. Range Wood

Required behavior:

- Tapping an identity selects and previews it.
- The selected identity remains visually clear through the existing selected
  row treatment and checkmark.
- Each row retains a minimum 44-point touch target and a clear accessibility
  label and selected value.
- The existing `Preview Guided Swing` action previews the currently selected
  identity.
- Existing tempo and ratio behavior remains intact.
- Existing Start and Stop behavior remains intact.
- No unrelated Control Room redesign is permitted.

## Asset Production and Documentation

Generate 15 original local WAV assets: five for each new identity.

Asset rules:

- Use project-owned, locally generated audio.
- Use clear lowercase snake-case names consistent with current identity assets.
- Prevent clipping in each rendered asset.
- Avoid excessive high-frequency energy, long noise beds, and uncontrolled
  tails.
- Keep files intelligible through an iPhone speaker without designing only for
  the speaker.

Update `SOURCE_MANIFEST.json` with one identity-level entry for each new
identity, following the current baseline identity records. Each entry must list
the five files and mark them as LIFE-IN-SYNC generated, project-owned audio.

Update `LICENSES.md` so its generated-audio section includes:

- `glass_line_*.wav`
- `air_cut_*.wav`
- `range_wood_*.wav`

The Xcode project uses filesystem-synchronized groups. Bundle inclusion must
still be verified from the built product or build resource output; file presence
alone is not sufficient proof.

## Rough Loudness Balance

This pass performs rough balancing, not final mastering.

Balance through:

- phase-level asset gain
- phase-level synthesis gain
- identity-level `outputGain`
- existing output soft limiting

Required outcomes:

- no clipping
- no painfully sharp transient
- no identity obviously overwhelms or disappears beside the others
- Glass Line remains bright without piercing
- Air Cut remains present without noise fatigue
- Range Wood remains substantial without approaching Heavy Steel's mass

Exact gain values are implementation decisions and must be documented in the
final implementation report. They cannot be treated as final until real-device
listening is complete.

## Implementation Scope

Expected changed files:

- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
- `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
- `LIFE-IN-SYNC/Garage/Metronome_Audio/SOURCE_MANIFEST.json`
- `LIFE-IN-SYNC/Garage/Metronome_Audio/LICENSES.md`
- 15 new WAV files under `LIFE-IN-SYNC/Garage/Metronome_Audio/`

Compile-required Garage tests or QA surfaces may be updated narrowly if enum
expansion requires it. No other files should change without a concrete
compile-time or verification reason.

## Verification Contract

Follow the repository's strict verification budget.

Required static checks:

- focused `xcrun swiftc -parse` on each changed Swift file
- `git diff --check`
- validate `SOURCE_MANIFEST.json` as JSON
- verify all 15 planned WAV files exist
- verify every new event-plan asset name maps to a bundled file
- verify all six identities are present in the Guided Swing selector order

Do not run a simulator, screenshots, Computer Use, or visual QA unless explicitly
requested.

Do not run more than one full Xcode build. A full build is optional only when
needed and must stop after 60 seconds. Do not retry a stalled build.

Runtime listening remains unverified by static checks. Final implementation
reporting must clearly state that identity distinction, perceived loudness,
iPhone speaker quality, headphone quality, and rapid-switch playback stability
require real listening.

## Acceptance Criteria

The implementation is complete only when:

1. Glass Line, Air Cut, and Range Wood exist in the current identity
   architecture.
2. Each new identity owns a distinct build, top, downswing, impact, and tail
   plan.
3. Each new identity uses five dedicated bundled local WAV assets.
4. Each new identity uses an identity-specific synthesis support path.
5. All six identities appear in the approved Control Room order.
6. Selecting any identity saves it and starts its full one-cycle preview.
7. The three baseline event plans remain unchanged except for explicitly
   reported compatibility work.
8. Existing routing, AppStorage keys, separate BPM memory, tempo and ratio
   behavior, count-in, Start, Stop, Resume, and Swing Capture behavior remain
   intact.
9. Manifest and license records cover every new WAV asset.
10. Static verification passes.
11. Final mastering is not claimed.

## Explicit Non-Goals

- final mastering or global normalization
- changes to Tour Whip, Heavy Steel, or Digital Vector character
- Metronome sound-library changes
- Tempo Builder UI redesign
- new settings or controls
- new persistence keys or migrations
- changes to tempo range, ratio behavior, count-in, rest, or session state
- remote or third-party audio
- simulator or visual QA without a separate explicit request

## Next Step After Implementation

Stop sound development after this pass and perform real listening approval on:

1. iPhone speaker
2. headphones

Only after that approval should final loudness normalization and mastering be
planned.
