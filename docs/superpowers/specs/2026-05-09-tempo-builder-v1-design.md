# Tempo Builder V1 Design

- Status: proposed design
- Date: 2026-05-09
- Scope: Garage module only
- Owner: Tempo Builder destination shell
- Source of truth alignment: `docs/canonical/CANONICAL_PRODUCT_SPEC.md`, `docs/architecture/ARCHITECTURE.md`, `docs/garage/GARAGE_REVAMP_BLUEPRINT.md`

## Decision Summary

Tempo Builder V1 becomes a standalone swing-rhythm instrument inside Garage.

The feature is centered on one primary saved `Tempo Profile`: a club-neutral rhythm fingerprint for the user's personal stock swing. The active experience is a circular 3-beat metronome dial used during reps. The post-set experience is a Performance Lab view that makes the saved profile feel premium, measurable, and personal without claiming automatic swing measurement.

## User Intent

The user wants Tempo Builder to improve swing rhythm during reps.

The product should feel like an instrument, not a lesson, game, or generic practice tracker. It should help the user discover a natural tempo, refine it technically, hear it clearly, and repeat the same rhythm across clubs.

## V1 Product Loop

1. The user opens Tempo Builder.
2. If no profile exists, the user chooses `Calibrate Profile` or `Start Default Metronome`.
3. Calibration uses a hybrid ladder plus tap flow to find a natural starting BPM.
4. The user fine-tunes BPM and a `Smooth` to `Snappy` feel slider.
5. The user practices a default 10-rep set against a circular 3-beat metronome.
6. After the set, the user rates the feel: `Grooved`, `Rushed`, `Late`, or `Lost`.
7. The app saves the set result into Tempo Profile history.
8. The Performance Lab opens with the Tempo Fingerprint first.

## Core Object: Tempo Profile

Tempo Profile is the durable product concept. It is not just a workout result.

V1 supports one primary profile. The architecture should leave room for multiple profiles later, but V1 should not expose a profile library.

Minimum profile fields:

- Profile name
- Target BPM
- Feel position from `Smooth` to `Snappy`
- Beat pattern version
- Impact emphasis setting
- Default rep target
- Sound style
- Haptic preference
- Created date
- Last practiced date
- Practice history entries

Default profile names:

- `My Stock Tempo`
- `Smooth Stock`
- `Controlled Tempo`
- `Impact Tempo`
- `Snappy Stock`

The app suggests a name after calibration and allows the user to edit it before saving.

## Beat Pattern

V1 uses a 3-beat classic golf swing pattern:

- Beat 1: `Takeaway`
- Beat 2: `Top`
- Beat 3: `Impact`

Beat 3 is the premium moment. It should receive the sharpest sound, strongest visual pulse, and optional haptic.

The metronome should support simple BPM behavior as a secondary mode, but the primary interaction should be the swing-pattern pulse.

## Feel Slider

The active screen exposes one major timing control:

`Smooth` to `Snappy`

The slider changes the spacing between the 3 beats while keeping the interface simple.

Product meaning:

- `Smooth`: longer 1-to-2 window, softer transition feel
- `Neutral`: stock swing rhythm
- `Snappy`: tighter transition and sharper impact arrival

Implementation should keep the exact millisecond math behind the UI unless the Performance Lab or an advanced sheet needs to reveal it.

## Sound Design

V1 sound direction is a clean digital metronome.

Audio behavior:

- Beat 1: clean tick
- Beat 2: slightly higher tick
- Beat 3: sharpest, brightest tick

Avoid ambient soundscapes, wellness tones, music beds, or overly playful sounds. Precision matters more than atmosphere.

The metronome service must be designed as a reliable local service with deterministic timing and no network dependency.

## Active Screen

The active screen is the Minimal Pocket Coach half of the hybrid direction.

Primary visual model:

- Circular tempo dial
- Three beat nodes around the circle
- Moving indicator traveling through Takeaway, Top, and Impact
- Impact node emphasized with a brighter glow
- BPM visible
- Current profile name visible
- Start / pause control
- Smooth-to-Snappy slider
- Optional rep count

Secondary visual:

- A restrained waveform or impact strip may sit below the dial if it does not clutter the during-reps view.

The active screen must be readable during practice and should avoid dense settings, charts, long copy, or training explanations.

## Advanced Controls Sheet

Advanced controls should live behind a sheet so the active instrument stays clean.

Controls:

- BPM
- Rep target
- Sound on/off
- Haptic on/off
- Impact emphasis
- Beat labels
- Tone intensity
- Save/update Tempo Profile

The sheet may expose exact values. The active screen should stay simple.

## Calibration

V1 calibration uses a hybrid ladder plus tap model.

Flow:

1. The app presents a small BPM ladder.
2. The user tries a few 3-beat swing-pattern pulses.
3. The user taps or nudges toward the rhythm that feels natural.
4. The app proposes a starting Tempo Profile.
5. The user fine-tunes BPM, feel, and profile name before saving.

Calibration should not imply camera, microphone, or swing detection in V1.

## Practice Set

Default set:

- 10 reps
- Editable in the advanced sheet

During reps, the app should count the set without interrupting after every swing.

After the set, the app asks for one quick feel rating:

- `Grooved`
- `Rushed`
- `Late`
- `Lost`

An optional short note can be attached to the set.

## Performance Lab

The Performance Lab is the technical half of the hybrid direction.

It opens with the Tempo Fingerprint, not a generic log.

Tempo Fingerprint content:

- Profile name
- BPM
- Smooth-to-Snappy feel position
- 3-beat pattern summary
- Impact emphasis
- Recent feel trend
- Best recent streak or repeatability cue
- Last practiced date

Secondary content:

- Practice set history
- Feel ratings over time
- Notes
- Total sets and total reps

The Performance Lab may feel technical and measurable, but it must be honest: V1 measures the user's chosen settings and self-reported set feel, not actual swing impact timing.

## Empty State

When no Tempo Profile exists, Tempo Builder shows two clear choices:

- `Calibrate Profile`
- `Start Default Metronome`

`Calibrate Profile` is the recommended path.

`Start Default Metronome` lets the user jump into the circular dial immediately with a sensible stock rhythm and save later.

## Data And Persistence

Tempo Builder should remain local-first.

Preferred V1 persistence:

- Use SwiftData only when the implementation phase confirms the model boundary and migration cost.
- If SwiftData schema changes are required, report the blocker before coding the persistence layer.
- If schema changes are deferred, support the first implementation with in-memory state and a clearly bounded persistence follow-up.

Potential model concepts:

- `GarageTempoProfile`
- `GarageTempoPracticeSet`
- `GarageTempoFeelRating`
- `GarageTempoBeatPattern`

These names are candidate design names, not approved implementation names.

## Service Boundary

Tempo Builder should introduce a module-local metronome service.

Responsibilities:

- Maintain BPM
- Maintain beat pattern
- Calculate beat timing from feel position
- Emit beat events
- Drive audio ticks
- Drive visual phase state
- Pause/resume cleanly
- Stop when the screen disappears

The service should not:

- Analyze video
- Listen to the microphone
- Infer swing quality
- Write data without explicit user action
- Depend on network services
- Change app-wide routing

## Garage Integration

Tempo Builder stays separate from Drill Plans, Focus Room, and Journal in V1.

Allowed integration:

- It remains launched from the current Garage Home Tempo Builder card.
- It uses Garage visual primitives such as `GarageProTheme`, `GarageProScaffold`, and `GarageProCard`.
- It may reuse existing Garage haptic helpers where appropriate.

Not allowed in V1:

- Routing Tempo Builder into Template Builder
- Creating new top-level modules
- Reworking Garage Home
- Changing Drill Plans or Focus Room behavior
- Adding cross-module dependencies

## Visual Direction

The approved direction is Hybrid:

- Active mode: Minimal Pocket Coach
- Review mode: Performance Lab

Active mode uses the Circular Tempo Dial as the centerpiece.

Design rules:

- Dark layered Garage surface
- Electric cyan for primary active cues
- Restrained warm impact accent only for Beat 3 if needed
- Tactile raised/inset controls
- No default List/Form surfaces
- No crowded dashboards during reps
- No long explanatory copy in the active state

## V1 Non-Goals

V1 does not include:

- Camera swing analysis
- Microphone impact detection
- Automatic swing tempo measurement
- Multiple profile library UI
- Club-specific tempo profiles
- Drill-plan integration
- Journal integration
- AI-generated coaching
- Network-backed sync
- A SwiftData migration unless explicitly approved during implementation planning

## Acceptance Criteria

- Tempo Builder can launch from the existing Garage route.
- No-profile users can calibrate a profile or start a default metronome.
- The active screen presents a circular 3-beat metronome dial.
- Beat 3 is clearly treated as Impact.
- The Smooth-to-Snappy slider changes beat spacing.
- The metronome uses clean digital ticks.
- Advanced controls stay out of the active screen by default.
- The default practice set is 10 reps and editable.
- The user rates set feel after the set.
- The Performance Lab opens with Tempo Fingerprint.
- The implementation stays Garage-local.
- The implementation does not imply automatic swing measurement.
- The implementation does not silently write user data.

## Open Implementation Questions

These should be resolved during implementation planning, not in the product design:

- Whether V1 persistence requires a SwiftData model addition or starts in-memory.
- Which iOS audio timing API gives the cleanest reliable metronome behavior for the current app target.
- Whether haptics should fire on Impact only by default.
- Whether the waveform strip belongs in V1 or should wait until after the circular dial is working.
