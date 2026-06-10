# Tempo Builder Metronome Sound Library Design

- Status: awaiting user review
- Scope: Garage Tempo Builder Metronome sound library only
- Date: 2026-06-10
- Owner surfaces:
  - `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
  - `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
- Product input: completed Grill Me session and June 9 screen-recording audit

## Objective

Replace the current Metronome sound profiles with ten unmistakably different generated click sounds that match their names, remain precise on every beat, and automatically use separate built-in-speaker and headphone recipes.

This first slice fixes the complaint that every public sound option feels like a minor variation of the same click. It does not redesign Guided Swing audio or perform broader Tempo Builder visual polish.

## Current Problem

The live Metronome already has the correct mechanical foundation:

- one continuous click on every beat
- audio-clock-synchronized pendulum and haptics
- live BPM adjustment
- one `Click Sound` entry in Control Room

The current sound library does not meet the product standard:

- all ten profiles pass through one shared click-generation function
- profile differences are mostly tuning constants inside the same synthesis shape
- aggressive shared transient shaping compresses their audible personalities
- tapping a row immediately changes the saved selection
- rows use three unclear categories rather than the approved two-family structure
- route detection is exposed only as display text; it does not select route-tuned recipes

## Locked Product Decisions

### Library Size And Families

The Metronome library contains exactly ten public sounds in two labeled sections.

#### Physical Materials

1. `Woodblock`
   - warm, dry, natural
2. `Rimshot`
   - sharp, bright, precise
3. `Leather Snap`
   - tight, muted, tactile
4. `Stone Knock`
   - solid, low, compact
5. `Glass Tick`
   - light, bright, brittle

#### Functional Tones

1. `Crisp Marker`
   - short, clear, high-definition beat marker
2. `Low Punch`
   - deep, firm, speaker-present beat marker
3. `Digital Tick`
   - clean, synthetic, surgical
4. `Soft Air`
   - light, unobtrusive, headphone-friendly
5. `Bright Signal`
   - clear, projecting, high-visibility beat marker

`Woodblock` is the default.

### Sound Quality Contract

Every sound must:

- audibly match its name
- be recognizable without seeing its name after brief familiarization
- begin with the same precise beat onset
- feel perceptually equal in loudness to the other nine sounds
- remain comfortable during extended practice
- use generated real-time synthesis only
- avoid bundled samples, system sounds, and third-party audio packages

Tone, body, waveform, and decay create the differences. Timing looseness does not.

## Independent Recipe Architecture

Each public sound owns two independent generated synthesis recipes:

- built-in speaker recipe
- headphone/external-output recipe

The recipes are not cosmetic parameter presets applied to one shared click shape. Each recipe independently defines the sound-generation behavior needed to create its named character:

- attack transient
- waveform generation
- fundamental and supporting frequency layers
- noise or texture generation when appropriate
- body response
- decay and tail
- drive and soft limiting
- perceived-loudness compensation

Shared infrastructure may handle frame timing, output limiting, and recipe dispatch. It must not flatten the ten sounds back into one audible family.

## Route Selection

### Route Families

Use the built-in speaker recipe only for the device's built-in speaker route.

Use the headphone recipe for:

- wired headphones
- Bluetooth outputs
- AirPlay
- external audio outputs
- unknown or unsupported routes

Unknown routes use the headphone recipe as the conservative fallback.

### Route Changes During Playback

When the output route changes while Metronome is running:

- cadence continues uninterrupted
- pendulum and haptic phase do not restart
- the active route family is updated
- the new recipe begins on the next beat boundary
- no partial click changes recipe midway through its transient

Route observation remains Garage-local and does not add app-wide audio-route state.

## Persistence And Migration

Continue using the existing AppStorage key:

- `garage.tempoBuilder.metronomeStartSound`

Do not add a new persistence schema.

Map current saved profile raw values to the closest new sound:

| Current Raw Value | New Sound |
|---|---|
| `hardwood` | `Woodblock` |
| `ball` | `Rimshot` |
| `steel` | `Bright Signal` |
| `leather` | `Leather Snap` |
| `stone` | `Stone Knock` |
| `rim` | `Rimshot` |
| `pulse` | `Digital Tick` |
| `glass` | `Glass Tick` |
| `signal` | `Crisp Marker` |
| `core` | `Low Punch` |

Unknown or invalid saved values fall back to `Woodblock`.

The obsolete `garage.tempoBuilder.metronomeImpactSound` value may remain stored for compatibility. The live Metronome does not read it as a separate click identity.

## Sound Library Interaction

Open the library from:

- `Control Room -> Click Sound`

### Layout

- Use two labeled sections: `Physical Materials` and `Functional Tones`.
- Show five rows in each section.
- Each row displays:
  - sound name
  - bright, outdoor-readable character description
- Rows do not display inline checkmarks, selection buttons, or expanding controls.

### Preview Behavior

- Tapping any row plays one isolated click.
- Tapping the currently selected sound still plays its preview.
- Previewing does not change the saved sound.
- Repeated preview taps cancel the active preview before starting the next click.
- Preview clicks never overlap.
- Preview automatically uses the current route-family recipe.

### Persistent Bottom Selection Bar

After the user previews a sound, show a stable bottom selection bar.

The bar displays:

- previewed sound name
- `Select` when the previewed sound differs from the saved sound
- `Selected` when the previewed sound matches the saved sound

Tapping `Select` saves the previewed sound and keeps the library open. Selection state lives only in this bottom bar; library rows remain visually clean.

## Live Metronome Behavior

- The selected sound is used for every beat.
- All beats remain uniform; there are no start, impact, accent, or subdivision identities.
- Selecting a new sound while the Metronome is stopped affects the next start.
- Live sound replacement during running playback is not part of this slice.
- Route-recipe replacement during running playback is required and occurs on the next beat.

## Failure Handling

- Unknown saved profile values fall back to `Woodblock`.
- Unknown route types use the headphone recipe.
- Route-detection failure does not stop playback.
- Preview-engine failure leaves the saved sound unchanged.
- Rapid preview taps silence the previous preview before starting the next.
- No preview or route change may reset the live Metronome cadence.

## Acceptance Criteria

### Recording Review

Use screen recordings for rapid comparison and iteration.

The recording review must confirm:

- every row plays one isolated non-overlapping click
- previewing does not save
- `Select` explicitly saves
- the bottom bar remains stable while browsing
- labels and descriptions match the heard sound character
- all ten options sound clearly different in direct comparison

### Final Physical Listening

Final acceptance requires physical listening through:

- built-in device speaker
- headphones

Test every sound at:

- `20 BPM`
- `45 BPM`
- `75 BPM`

Each sound passes only if:

- onset remains precisely on the beat
- loudness feels balanced against the other sounds
- its character remains recognizable
- it is comfortable during repeated listening
- built-in speaker and headphone recipes both preserve the intended identity

The library as a whole must pass a blind-recognition check after brief familiarization.

## Out Of Scope

Do not include any of the following in this implementation slice:

- Guided Swing sound redesign
- Guided Swing countdown or timeline cleanup
- stable Start, Pause, Resume, and Stop control redesign
- general Control Room typography or contrast polish outside the Metronome sound library
- Metronome pendulum redesign
- public volume controls
- bundled audio samples
- app-wide route-management architecture
- persistence schema changes

## Done Conditions

This slice is complete when:

1. The live Metronome exposes exactly ten approved sounds in two approved sections.
2. Every sound uses independent speaker and headphone synthesis recipes.
3. Existing saved values migrate to the approved nearest equivalents.
4. Previewing is isolated, non-overlapping, and does not save.
5. Explicit selection uses the persistent bottom bar.
6. Route changes switch recipes on the next beat without resetting cadence.
7. Focused parse checks and `git diff --check` pass.
8. Recording review passes.
9. Physical speaker and headphone listening passes at 20, 45, and 75 BPM.
