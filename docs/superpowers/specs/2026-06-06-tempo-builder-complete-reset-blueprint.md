# Tempo Builder Complete Reset Blueprint

- Status: proposed replacement design; awaiting user review
- Scope: Garage module only
- Date: 2026-06-06
- Owner surface: Tempo Builder
- Implementation status: blueprint only; no UI, audio, routing, camera, or persistence changes in this pass

## Executive Verdict

Kill the current Tempo Builder identity and rebuild the live surface as one minimal premium rhythm service with two full-screen tools:

1. **Metronome** opens first and provides a large physical pendulum, adjustable speed, and an original library of ten precise click sounds.
2. **Guided Swing** sits one full-page swipe to the right and provides a continuous, abstract, forceful swing sound with a restrained traveling-light visual.

A small camera action launches a separate **Tempo Calibration** flow. Calibration records one continuous down-the-line session, accepts ten valid swings, uses body motion plus impact audio to calculate a recommendation privately, then presents only:

- recommended tempo
- Preview
- Use This Tempo

Tempo Builder exists to help the golfer hear a rhythm repeatedly until body and tempo feel synchronized. It is not a dashboard, technical analyzer, preset system, soundboard, or AI coach.

## Product Promise

> Hear the rhythm. Repeat it. Build it into your swing.

## Non-Negotiable Identity

Tempo Builder is:

- a focused daily rhythm tool
- immediately useful without setup
- audio-first while the golfer looks at the ball
- minimal enough to understand in seconds
- premium, dark, tactile, and restrained
- locally generated and locally analyzed

Tempo Builder is not:

- a swing-shape selector
- a ratio trainer
- a club-preset system
- a technical data sheet
- an AI coaching surface
- an instrument carousel
- a settings laboratory
- a novelty soundboard
- a neon cockpit

## Locked User Decisions

### Core System

- Tempo Builder is a dual system.
- Metronome is the first/default page.
- Guided Swing is one full-page swipe to the right.
- The two pages may run separately.
- Guided Swing includes an optional `Clicks` toggle that layers the selected Metronome click.
- Guided Swing automatically follows the Metronome tempo.

### Metronome

- The main visual is a large physical pendulum-inspired instrument.
- Speed uses a horizontal slider.
- Practical range is `40–120 BPM`.
- The BPM number is large and visible.
- The beat is one clean repeating click with no subdivisions or accented first beat.
- The click library contains ten simple original sounds.
- The library opens in a dedicated sheet.
- Tapping a sound previews it immediately.
- Sounds may evoke real-world or restrained sci-fi sources, but no external samples or sound packs are allowed.

### Guided Swing

- Guided Swing uses a continuous sound across the swing motion.
- The sounds must feel striking, abstract, unique, strong, and non-corny.
- The library contains three signature sounds.
- The library opens in a dedicated sheet.
- The visual is a light traveling along one restrained swing arc.
- The light disappears during the rest interval.
- Automatic looping is the default practice behavior.
- Loop controls show one dominant Start/Stop action.
- Rest interval stays in settings.
- Rest choices are `3s`, `5s`, `8s`, and `10s`.

### Calibration

- Calibration is a separate flow launched from a small camera button.
- The camera position supported first is down-the-line only.
- Calibration captures one continuous session.
- The golfer swings whenever ready.
- The app detects address and speaks `Swing when ready`.
- Body motion plus impact audio determine swing timing.
- Invalid or low-confidence swings are rejected automatically.
- Calibration continues until ten valid swings are accepted.
- The recommendation favors the golfer's natural tempo, adjusted slightly toward a smoother, unhurried cadence.
- Calibration math remains private.
- Results show only the recommended tempo, Preview, and Use This Tempo.
- Applying the recommendation always requires explicit confirmation.
- Calibration recommendations are saved in a simple history.

### Originality Constraint

Implementation must not pull code, sound assets, or implementations from:

- external repositories
- coding plugins
- coding skills
- downloaded sound packs
- third-party dependencies
- copied reference implementations

All sound design must be authored as original Garage-local DSP inside LIFE IN SYNC.

## Completed Recommendations

The remaining unresolved choices are locked as follows:

| Decision | Recommendation |
|---|---|
| Metronome BPM display | Large BPM number above the slider |
| Page navigation | Natural full-screen swipe with two subtle page indicators |
| Guided Swing timing | Automatically follows Metronome BPM |
| Combined clicks toggle | Visible beneath the Guided Swing Start button |
| Guided Swing rest visual | Arc light disappears during rest |
| Rest interval choices | `3s`, `5s`, `8s`, `10s` |
| Calibration entry | Small camera button shared across both pages |
| Saved recommendations | Simple Calibration History sheet |
| Running controls | One dominant Stop button; lock speed and sound changes while running |
| Existing identity | Remove all current instrument, swing-shape, ratio, Engine Room, neon cockpit, and technical phase UI |

## Approaches Considered

### Selected: Two Focused Full-Screen Tools

Metronome and Guided Swing are sibling pages sharing one tempo value.

Why selected:

- preserves a pure metronome
- gives Guided Swing enough visual and sonic space
- makes both tools understandable without explanation
- allows optional layering without making combined mode a third product
- keeps calibration separate from daily use

### Rejected: One Combined Dashboard

Both tools and their controls appear on one screen.

Why rejected:

- immediately recreates the clutter problem
- weakens the metronome as the default identity
- encourages settings and metrics to dominate practice

### Rejected: Three-Page System

Metronome, Guided Swing, and Combined become separate swipe pages.

Why rejected:

- combined mode is only a toggle, not a distinct tool
- adds navigation and product language without adding capability
- makes the service feel like a mode collection again

## Source-of-Truth Alignment

This blueprint follows:

- `docs/canonical/CANONICAL_PRODUCT_SPEC.md`
  - Garage owns Tempo Builder rhythm rehearsal.
  - Garage remains local-first and tool-first.
- `docs/architecture/ARCHITECTURE.md`
  - Tempo Builder remains a Garage-local runtime session.
  - No shell, cross-module, or global-state expansion is needed.
- Existing Garage design primitives
  - premium dark surfaces
  - controlled depth and restrained motion
  - no default `List` or `Form`

### Confirmed Live Route

The active route remains:

`GarageView.swift -> GarageNavigationDestination.tempoBuilder -> GarageTempoBuilderView()`

The current live seam is:

- `LIFE-IN-SYNC/Garage/GarageView.swift`
- `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
- `LIFE-IN-SYNC/Garage/EngineRoomSettingsView.swift`
- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`
- `LIFE-IN-SYNC/Garage/SwingCaptureView.swift`

`GarageTempoWizard.swift` remains legacy and must not become the new implementation base.

## Current-State Diagnosis

### Keep

- Garage-owned navigation route
- real-time `AVAudioEngine` and `AVAudioSourceNode` foundation
- generated-audio capability
- separate continuous-loop and one-cycle preview behavior
- capture-compatible audio session
- Garage-local state ownership
- existing back navigation

### Replace

- current `GarageTempoBuilderView` visual hierarchy
- current instrument carousel
- current central build dial
- current pendulum implementation if it cannot support the new minimal hierarchy
- current settings presentation
- current Garage Home Tempo Builder preview
- current user-facing sound profile names

### Remove From The User Experience

- `Build` instrument language
- `Pressure` instrument language
- instrument selection
- swing-shape selection
- `Athletic`, `Balanced`, and `Stretched`
- visible ratio values
- technical phase labels
- training maps
- micro maps
- `LIVE` / `READY` status badges
- sound-skin language
- `Engine Room`
- neon green/yellow cockpit identity
- club or practice-type tempo presets
- dense explanation copy

### Internal Cleanup Rule

Old engine enums and synthesis helpers may remain temporarily only when needed to keep implementation increments safe. They must not leak into the new product language or become permanent compatibility layers.

## Information Architecture

```text
Garage Home
  -> Tempo Builder
      -> Metronome page (default)
          -> Click Library sheet
          -> Settings sheet
          -> Tempo Calibration
      -> Guided Swing page (swipe right)
          -> Guided Sound Library sheet
          -> Settings sheet
          -> Tempo Calibration
      -> Calibration History sheet
```

## Shared Tempo Session Model

Both daily tools share one Garage-local session configuration:

- `beatsPerMinute`
- selected metronome click
- selected guided sound
- guided clicks enabled
- rest interval
- active page
- playback state

Rules:

- There is one tempo value, not separate Metronome and Guided Swing speeds.
- Adjusting tempo while stopped updates both tools.
- Starting either page stops any playback owned by the other page.
- Swiping pages while running is disabled or stops playback before completing the transition.
- Sound and speed controls are locked while running.
- Preview playback never starts the continuous loop.
- Dismissing any library stops its active preview.

## Screen Blueprint

### 1. Garage Home Entry

Purpose: launch the daily rhythm tool without implying presets or technical analysis.

Hierarchy:

1. `Tempo Builder`
2. short promise: `Build a rhythm you can repeat.`
3. simple pendulum/rhythm artwork
4. current saved BPM as secondary information
5. `Open Tempo Builder`

Remove:

- ratio preview
- club chips
- multiple metrics
- technical timing claims

### 2. Shared Top Bar

Visible on both pages while stopped:

- back
- centered `Tempo Builder`
- small camera button
- small settings button

While running:

- keep back available with stop-before-dismiss behavior
- hide or disable camera and settings
- avoid status badges

The top bar must not compete with the active tool.

### 3. Metronome Page

Metronome opens by default.

Ready hierarchy:

1. large pendulum occupying the visual center
2. large BPM value
3. horizontal tempo slider
4. current click sound button
5. dominant Start button
6. two subtle page indicators

Running hierarchy:

1. animated pendulum
2. BPM value
3. dominant Stop button
4. subtle page indicators

Behavior:

- Pendulum movement and click onset use the same audio timing source.
- The click occurs at the pendulum endpoint.
- Speed range is `40–120 BPM`.
- Slider uses whole-BPM steps.
- Slider changes are available only while stopped.
- Start begins immediately without a countdown.
- Stop fades cleanly and returns the pendulum to center.
- Reduce Motion replaces full travel with restrained endpoint emphasis while preserving audio timing.

### 4. Metronome Click Library

Presentation:

- dedicated medium/large sheet
- one clean two-column grid
- ten sound tiles
- selected state is obvious but restrained
- tapping a tile previews it immediately and selects it
- no descriptions longer than a short character label

Proposed original click set:

1. `Hardwood` — dry, warm, precise
2. `Ball` — compact golf-ball-like strike
3. `Steel` — short restrained metal tap
4. `Leather` — tight muted snap
5. `Stone` — dense natural tick
6. `Rim` — crisp dry rim click
7. `Pulse` — short low synthetic transient
8. `Glass` — controlled bright ping
9. `Signal` — clean restrained sci-fi marker
10. `Core` — firm abstract impact

Curation law:

- every sound must remain intelligible at low phone volume
- every sound must tolerate hundreds of repetitions
- no long tails
- no comedy, arcade, laser-gun, toy, or cinematic effects
- loudness must be normalized across the library

### 5. Guided Swing Page

Purpose: guide the complete motion through one continuous sound shape.

Ready hierarchy:

1. restrained swing arc
2. selected guided sound button
3. dominant Start button
4. visible `Clicks` toggle beneath Start
5. two subtle page indicators

Running hierarchy:

1. traveling light across the swing arc
2. dominant Stop button
3. small `Clicks On` state only when enabled
4. no phase labels or metrics

Sound behavior:

- one continuous sound begins at the start of the swing cycle
- sound develops through the backswing
- sound changes direction/character through transition and release
- impact resolves strongly without becoming a novelty strike effect
- silence fills the selected rest interval
- loop repeats automatically
- selected Metronome click layers at the shared beat when `Clicks` is enabled

Visual behavior:

- the traveling light follows the exact guided-audio timing
- the arc remains extremely simple
- no address/top/impact labels
- no nodes, gates, tick marks, ratios, or phase text
- the active light disappears during rest
- the visual is readable peripherally but audio remains primary

### 6. Guided Sound Library

Presentation matches the Metronome library but contains three larger choices.

Proposed original signatures:

1. `Tension`
   - dense, controlled rise
   - strong directional release
   - dry, authoritative resolution
2. `Vector`
   - precise synthetic movement
   - restrained sci-fi character
   - sharp but non-arcade resolution
3. `Mass`
   - low physical weight
   - gradual pressure and acceleration
   - compact forceful resolution

The names are working names and must survive listening review before shipping.

### 7. Settings Sheet

One shared minimal settings sheet:

- Rest Between Swings: `3s`, `5s`, `8s`, `10s`
- Calibration History
- Run Calibration

Do not place these in settings:

- tempo slider
- click selection
- guided sound selection
- swing ratios
- subdivisions
- sound-shaping controls
- phase controls
- advanced DSP parameters

`Engine Room` is deleted. Do not rename it to another branded room.

## Tempo Calibration Blueprint

### Product Boundary

Calibration is an occasional setup tool that recommends a tempo. It is not the daily Tempo Builder experience and is not a biomechanical coaching product.

It must not claim:

- objectively best tempo
- professional-equivalent swing analysis
- injury or performance guarantees
- real-time coaching
- complete swing understanding from pose data

### Calibration Flow

#### Step 1: Setup

- explain down-the-line phone placement with one simple visual
- require full body and club area to fit in frame
- explain that ten valid swings are required
- request camera and microphone access
- start one continuous capture session

#### Step 2: Address Detection

- process live video frames locally
- identify a visible full-body pose
- detect a short stable address window
- when confidence passes threshold, speak `Swing when ready`
- do not use a countdown
- do not prompt again until the current swing has completed or timed out

#### Step 3: Swing Detection

- use body motion to identify movement onset, top, and return through impact region
- use microphone transient detection to strengthen impact timing
- calculate confidence for the complete event sequence
- reject invalid swings automatically
- continue until ten valid swings are accepted

Visible feedback stays minimal:

- `4 of 10 swings captured`
- `Swing not captured. Reset and try again.`
- `Address found. Swing when ready.`

Do not show live joints, skeletons, charts, metrics, or technical confidence values.

#### Step 4: Recommendation

Private calculation may use:

- swing duration
- backswing duration
- downswing duration
- transition timing
- impact timing confidence
- swing-to-swing cadence consistency
- outlier rejection

Recommendation rule:

1. Find the stable center of the golfer's valid natural swings.
2. Reject timing outliers.
3. Weight repeatability more heavily than raw speed.
4. Nudge the final recommendation slightly toward a smoother, unhurried cadence.
5. Clamp the recommendation to the supported `40–120 BPM` range.

The algorithm must be deterministic, local, explainable in code, and testable with recorded fixtures. No AI model or remote service is required.

#### Step 5: Result

Show only:

- `Recommended Tempo`
- large BPM value
- Preview
- Use This Tempo
- secondary `Not Now`

`Preview` plays a short Metronome preview using the currently selected click.

`Use This Tempo`:

- explicitly applies the recommendation
- updates the shared Metronome and Guided Swing tempo
- saves the accepted recommendation to history
- returns to the Metronome page

### Calibration History

Keep history intentionally small:

- date
- accepted recommended BPM
- Preview
- Use This Tempo
- delete entry

Do not show:

- detailed metrics
- charts
- trend claims
- swing scores
- pose data
- recorded video archive by default

### Calibration Architecture Risk

The existing `SwingCaptureView` records camera and microphone media but does not currently provide live pose-based address detection. The existing Garage timestamp/pose support is not a finished active biomechanical analysis engine.

Calibration therefore requires a dedicated Garage-local capture coordinator with:

- `AVCaptureVideoDataOutput` for live Vision pose frames
- audio sample access or deterministic post-capture transient analysis
- continuous session segmentation
- a local address/swing state machine
- confidence and rejection rules
- careful device testing

This is the highest-risk portion of the blueprint and must not block the daily two-page tool rebuild.

## Persistence Blueprint

### Daily Preferences

Persist:

- current BPM
- selected Metronome click
- selected Guided Swing sound
- Guided Swing clicks enabled
- rest interval

These are user preferences, not practice records.

### Calibration Recommendations

Persist accepted recommendations only.

Recommended model fields:

- stable UUID
- created date
- recommended BPM

Do not persist raw pose frames, audio features, hidden metrics, or calibration video unless a later explicit product decision requires it.

### Migration Risk

Saved calibration history introduces new persistent data. Implement it only as a deliberate Garage-local SwiftData model addition with migration and compatibility verification. Do not mutate existing Garage record schemas to squeeze calibration into unrelated models.

## Audio Architecture

### Required Engine Capabilities

The new Garage-local engine must support:

- pure repeating metronome click
- ten original synthesized click profiles
- continuous Guided Swing loop
- three original continuous guided profiles
- optional click layering over Guided Swing
- one-shot click preview
- one-cycle Guided Swing preview
- clean start
- short clean stop fade
- live synchronization between audio and visual progress

### Architecture Direction

Preserve the current real-time generated-audio foundation, but replace the user-facing `GarageTempoInstrumentMode` / `ElasticSlingshotSoundProfile` product model with clearer internal concepts:

- `TempoTool`: metronome, guidedSwing
- `MetronomeClickProfile`
- `GuidedSwingProfile`
- `TempoPlaybackConfiguration`

Do not force the ten click profiles and three guided profiles into one shared enum. They have different synthesis contracts.

### Timing Law

- The audio engine is the timing authority.
- Visuals derive progress from the same playback configuration and start timestamp.
- Metronome click timing must not be driven by SwiftUI animation callbacks.
- Guided sound and optional click layer must remain sample-aligned.
- BPM changes occur only while stopped in v1.

## Visual Direction

### Keep

- deep dark Garage atmosphere
- soft depth
- thin edge light
- controlled highlight color
- tactile controls
- compact premium typography

### Kill

- neon cockpit presentation
- oversized glowing technical rings
- decorative tick marks
- status chips
- fake instrumentation
- dense cards
- gradients that exist only to look futuristic
- explanatory paragraphs inside the tool

### Motion

- default interaction animation remains `.spring(response: 0.35, dampingFraction: 0.8)`
- pendulum motion must feel weighted, not playful
- guided arc motion must feel continuous and deliberate
- no bouncing, confetti, pulsing dashboards, or attention-seeking transitions

## Copy System

Use:

- `Tempo Builder`
- `Metronome`
- `Guided Swing`
- `Clicks`
- `Sounds`
- `Rest Between Swings`
- `Run Calibration`
- `Calibration History`
- `Recommended Tempo`
- `Preview`
- `Use This Tempo`
- `Swing when ready`

Remove:

- `Engine Room`
- `Control Room`
- `Build`
- `Pressure`
- `Sound Skin`
- `Instrument`
- `Swing Shape`
- `Training Map`
- `Load`
- `Release`
- `Athletic`
- `Balanced`
- `Stretched`
- ratio copy
- Jake Knapp's name from product UI

Jake Knapp remains a private creative reference for smooth, unhurried cadence, not a named preset or implied endorsement.

## Failure Handling

### Daily Tools

- audio-session failure: show a compact retry state
- preview interruption: stop cleanly and return selection UI to idle
- app backgrounding: stop playback
- route dismissal: stop playback
- camera launch while playing: stop playback first

### Calibration

- camera or microphone denied: explain required permission and provide system-settings action
- body not fully visible: show one direct placement correction
- address not detected: remain waiting without repeated voice spam
- invalid swing: reject it and request another
- interrupted session: allow restart; do not save partial recommendation
- fewer than ten valid swings: do not generate a recommendation
- analysis failure: do not fabricate a tempo

## Accessibility

- all sound choices have distinct spoken names
- click previews stop before a new preview begins
- VoiceOver describes selected sound and BPM
- slider supports accessibility increments
- Reduce Motion preserves timing comprehension without full pendulum/arc travel
- calibration voice prompt has a visible equivalent
- calibration status never relies on color alone

## Implementation Phases

### Phase 0: Destructive UI Inventory

- verify live route again
- identify every current Tempo Builder component as keep, replace, or delete
- confirm no unrelated Garage callers depend on old UI-only types
- write focused audio-engine tests around current timing before refactoring

Exit condition:

- deletion list and engine safety boundary are proven

### Phase 1: New Session Model And Pure Metronome

- introduce the shared Tempo Builder session configuration
- implement the pure Metronome playback contract
- author and normalize ten original click profiles
- implement click previews
- build the new minimal Metronome page

Exit condition:

- Metronome is useful by itself and remains accurate across `40–120 BPM`

### Phase 2: Guided Swing

- implement three original continuous guided profiles
- implement shared-BPM timing
- implement optional sample-aligned click layering
- implement automatic loop and rest interval
- build the minimal Guided Swing page and traveling-light visual

Exit condition:

- both pages work independently and combined mode remains synchronized

### Phase 3: Full Identity Removal

- delete the current carousel, build dial, micro map, phase UI, and settings hierarchy
- replace Garage Home preview
- remove user-facing instrument, ratio, swing-shape, and sound-skin language
- replace `EngineRoomSettingsView` with the minimal shared settings/library surfaces

Exit condition:

- no current Tempo Builder identity remains visible in the live route

### Phase 4: Preference Persistence And Polish

- persist daily preferences
- complete accessibility behavior
- verify interruption/background behavior
- perform sound curation and loudness balancing
- perform device visual QA

Exit condition:

- daily Tempo Builder is shippable before calibration exists

### Phase 5: Calibration Technical Prototype

- build a down-the-line live pose/address detection spike
- prove continuous capture plus impact-audio detection
- prove valid-swing segmentation and rejection
- test with recorded fixtures and real device sessions
- do not connect prototype output to saved user preferences yet

Exit condition:

- ten-swing recommendation is repeatable enough to justify product integration

### Phase 6: Calibration Product Flow

- build setup, capture, progress, result, and history surfaces
- add explicit Use This Tempo confirmation
- add deliberate SwiftData history model and migration verification
- verify no hidden metrics leak into the UI

Exit condition:

- calibration reliably produces or honestly refuses a recommendation

## Verification Plan

### Static

- `git diff --check`
- focused Swift parse checks for changed Garage files
- no new third-party dependencies
- no external audio assets
- no changes outside Garage unless compilation registration requires them

### Audio

- verify click interval accuracy at `40`, `60`, `75`, `90`, and `120 BPM`
- verify all ten click profiles are audibly distinct
- verify all ten click profiles are loudness-balanced
- verify all three guided profiles are audibly distinct
- verify Guided Swing follows shared BPM
- verify optional clicks remain aligned across long loops
- verify preview never starts continuous playback
- verify Stop has no pop or lingering tail
- perform real-device listening review; simulator-only proof is insufficient

### UI

- verify live route opens directly to Metronome
- verify one full-page swipe reveals Guided Swing
- verify no dashboard clutter or technical metrics remain
- verify settings and libraries do not become endless scroll surfaces
- verify running state exposes one dominant Stop action
- verify controls lock while running
- verify Reduce Motion and VoiceOver

### Calibration

- verify down-the-line setup guidance
- verify spoken and visible address confirmation
- verify low-confidence swings are rejected
- verify capture continues until ten valid swings
- verify no recommendation appears with fewer than ten valid swings
- verify result shows only BPM, Preview, and Use This Tempo
- verify recommendation applies only after confirmation
- verify history saves only accepted recommendations
- verify camera and microphone denial states
- verify real-device performance and thermal behavior

## Definition Of Done

The reset is complete when:

- Tempo Builder opens to a minimal premium Metronome.
- Guided Swing is one swipe away and feels like a second focused tool.
- The two tools share one tempo.
- Ten original click sounds are useful, distinct, and non-corny.
- Three original Guided Swing sounds are strong, abstract, and repeatable.
- Combined clicks work without becoming a third mode.
- All current instrument, swing-shape, ratio, phase, Engine Room, and neon cockpit identity is absent from the live experience.
- The daily tools work independently of calibration.
- Calibration either produces a trustworthy recommendation from ten valid swings or honestly refuses.
- The user sees no technical data clutter.
- No external repositories, coding plugins, coding skills, dependencies, or sound assets were used.

## Explicit Non-Goals

- named professional golfer presets
- club-specific tempo
- multiple saved daily tempo profiles
- visible ratio controls
- musical subdivisions
- advanced sound editing
- live swing coaching
- biomechanical scoring
- detailed calibration data sheets
- trend charts
- cloud analysis
- autonomous recommendation application
- external audio samples

## Final Product Test

A golfer should be able to open Tempo Builder, press Start, place the phone down, and groove a rhythm without reading, configuring, or watching a dashboard.

When they want help finding a starting tempo, Calibration should quietly do the technical work, let them hear the recommendation, and wait for permission before applying it.
