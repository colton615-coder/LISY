# Tempo Builder Spec Improvement Plan

- Status: product direction locked; ready for phased implementation
- Scope: Garage module only
- Date: 2026-06-05
- Owner surface: Tempo Builder
- Implementation status: spec only; no UI, audio, routing, or persistence changes in this pass

## Executive Summary

Tempo Builder should become a premium anti-rush swing rhythm trainer built around one trusted personal tempo.

The product promise is:

> Open your tempo. Press Start. Hear the rhythm. Swing smoother. Reset. Repeat.

The current routed implementation has a useful Garage-local audio engine and continuous-loop foundation, but its product hierarchy is diluted by instrument modes, swing-shape choices, sound-skin browsing, technical ratio language, and a running visual that asks for too much attention.

The next implementation should refine the current `Home -> Running -> Tune` structure rather than replace it:

- Ready state recalls one personal tempo and makes Start immediate.
- Running state becomes audio-first and peripheral-only.
- Engine Room becomes Control Room.
- Control Room exposes only tempo speed, break between swings, and preview audio.
- Audio combines precise metronome timing with one guided swing-duration cue.
- Club presets, swing-shape choices, and visible sound customization are removed or deferred.

This direction stays inside the live Garage Tempo Builder seam and preserves the existing real-time `AVAudioEngine` / `AVAudioSourceNode` architecture.

## Product Definition

### One-Sentence Promise

Tempo Builder helps the golfer stop rushing by guiding every swing through one repeatable personal rhythm they can hear while looking at the ball.

### Training Problem

The user tends to:

- rush the takeaway
- rush or skip the transition from the top
- make the whole swing feel jumpy and uneven

Tempo Builder must make the start calmer, the transition more deliberate, and the complete motion feel connected.

### Product Identity

Tempo Builder is:

- a premium anti-rush swing rhythm trainer
- a personal tempo recall tool
- an audio-first instrument used while actually swinging
- a continuous practice loop with deliberate reset space

Tempo Builder is not:

- a club-preset system
- a generic metronome
- a soundboard
- a fake AI coach
- a swing analyzer
- a dense settings lab
- a dashboard that competes with the ball

### Core Experience Principle

> Stop rushing. Hear the rhythm. Swing with it. Repeat.

## Source-of-Truth Alignment

This plan follows:

- `docs/canonical/CANONICAL_PRODUCT_SPEC.md`
  - Garage owns Tempo Builder rhythm rehearsal.
  - Flagship surfaces should feel dark, tactile, premium, and tool-first.
  - Non-AI behavior remains local-first and offline-first.
- `docs/architecture/ARCHITECTURE.md`
  - Tempo Builder remains a Garage-local detail flow.
  - No shell, cross-module, or global-state expansion is required.
  - Existing module-scoped state and design patterns should be preserved.

### Confirmed Live Route

The active route is:

`GarageView.swift -> GarageNavigationDestination.tempoBuilder -> GarageTempoBuilderView()`

The live implementation surface is currently:

- `LIFE-IN-SYNC/Garage/GarageView.swift`
- `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
- `LIFE-IN-SYNC/Garage/EngineRoomSettingsView.swift`
- `LIFE-IN-SYNC/Garage/ElasticSlingshotAudioEngine.swift`

`GarageTempoWizard.swift` must not be treated as the live Tempo Builder surface unless routing changes later.

## Current-State Diagnosis

### What Already Supports The Direction

- Garage Home already launches a dedicated Tempo Builder flow.
- The live screen already separates ready and running presentation.
- Continuous playback and one-cycle preview paths already exist.
- The audio path is generated in real time and remains Garage-local.
- Break-between-swings already exists as local recipe state.
- Audio and visual timing already derive from shared tempo logic.
- Swing Capture already coexists with the Tempo Builder audio session.

### What Conflicts With The Locked Direction

- Ready state asks the user to choose between separate `Metronome` and `Build` instruments.
- The main screen foregrounds swing-shape and ratio concepts.
- Control settings expose instrument mode, swing shape, and multiple sound skins.
- `Engine Room` is fake-clever language and should become `Control Room`.
- Start copy changes according to instrument mode instead of starting one trusted rhythm.
- The running visual is a central instrument with multiple labels and landmarks rather than a quiet peripheral cue.
- Garage Home currently previews `Full Swing`, `Wedges`, and `Putting`, which implies club or practice-type tempo presets.
- The live screen defaults to in-memory state and does not currently guarantee recall of one saved personal tempo.

## Locked Decisions

### Product

- The main job is stopping a rushed swing.
- The user practices with audio while actually swinging.
- The experience must feel premium, focused, and repeatable.
- The product trains one consistent personal tempo identity.

### Flow

- Keep the general `Home -> Running -> Tune` flow.
- Ready state shows the trusted tempo already loaded.
- Start is the dominant action.
- Running loops continuously until stopped.
- Tune opens a minimal Control Room.

### Audio

- Use a two-layer audio model:
  - precise metronome layer
  - guided swing-duration cue layer
- Build slowly into each swing.
- Include a clear launch/start cue.
- Guide the swing duration without cheesy voice coaching.
- Preserve deliberate reset space before the next rep.
- Preview plays one representative cycle and does not begin the live loop.

### Visual

- The screen is secondary while running.
- Running visuals are subtle peripheral stimuli.
- Preferred direction is one restrained pulsating orb or one bright light traveling across a simple arc.
- Visual motion supports the audio timing and never becomes a separate training model.

### Controls

Control Room exposes only:

- tempo speed
- break between swings
- preview audio

### Language

- Rename `Engine Room` to `Control Room`.
- Prefer practical training language over branded mode names or technical recipe language.
- Keep copy beginner-readable and usable during practice.

## Explicit Removals And Deferrals

### Remove From The Primary Experience

- Driver / irons / wedges presets
- club-family tempo differences
- `Full Swing / Wedges / Putting` tempo chips on Garage Home
- separate user-facing `Metronome` and `Build` instrument modes
- swing-shape choices from Ready and Control Room
- raw ratio language from the primary experience
- visible sound-skin browsing
- dense running metrics and text
- Start button copy tied to an instrument name

### Defer Unless Revalidated

- alternate audio characters
- multiple running visual styles
- advanced subdivision controls
- haptic customization
- pause/resume behavior separate from Stop
- detailed timing diagnostics
- multiple saved tempo setups

### Preserve Internally When Useful

Existing engine enums or parameters may remain temporarily as implementation details when removing them would create unnecessary audio risk. They must not continue to define the user-facing product hierarchy.

## Core Flow

### 1. Garage Home Entry

Purpose: recall the user's trusted personal tempo and launch training immediately.

Required behavior:

- Tempo Builder remains a Garage-owned service.
- The preview communicates one personal tempo, not club or practice-type presets.
- The entry point promises smoother rhythm and less rushing.
- Tapping the service opens the Ready state with the trusted setup loaded.

Recommended hierarchy:

1. `Tempo Builder`
2. saved tempo value or plain-language tempo identity
3. short anti-rush promise
4. clear launch affordance

Do not show:

- club chips
- ratio as the main identity
- sound-character options
- multiple presets

### 2. Ready State

Purpose: make the trusted setup obvious and make Start effortless.

Required hierarchy:

1. personal tempo identity
2. dominant Start action
3. quiet explanation of the loop
4. Control Room access
5. existing back and Swing Capture access where appropriate

Recommended copy:

- Title: `Your Swing Tempo`
- Support: `A steady rhythm to smooth the start and transition.`
- Primary action: `Start`
- Tune action: `Control Room`

Ready state should communicate:

`Build -> Swing -> Reset`

It should not ask the user to choose an instrument, sound skin, club, or swing shape before starting.

### 3. Running State

Purpose: guide repeated swings while the user watches the ball.

Required behavior:

- Start immediately enters a continuous loop.
- Audio is the primary guide.
- The current loop remains understandable through peripheral vision.
- Stop is the only dominant on-screen control.
- Control Room may remain accessible only if changes can be made safely without interrupting the live rhythm.
- The screen avoids paragraphs, metrics, selectors, and detailed phase maps.

Recommended visible elements:

- one peripheral orb or arc-light cue
- one short state label at most: `Build`, `Swing`, or `Reset`
- one Stop action
- subdued back, capture, and settings affordances

The user should be able to put the phone down after pressing Start.

### 4. Control Room / Tune State

Purpose: tune the small number of variables that materially affect training.

Required controls:

1. `Tempo Speed`
2. `Break Between Swings`
3. `Preview Audio`

Required behavior:

- Changes remain local to Tempo Builder.
- Tempo changes update the preview and live loop from the same timing source.
- Break changes affect reset space only.
- Preview plays exactly one representative cycle.
- Preview must not overlap itself or silently start continuous playback.
- The sheet stops preview playback when dismissed.

Do not show:

- Instrument
- Swing Shape
- ratio choices
- sound-skin list
- club presets
- advanced diagnostic values

## Control Room Requirements

Control Room is a minimal tuning surface, not an advanced settings lab.

Its visible content must be limited to:

1. `Tempo Speed`
2. `Break Between Swings`
3. `Preview Audio`

Required interaction contract:

- Tempo Speed changes the one personal rhythm without introducing presets.
- Break Between Swings changes only the reset space between reps.
- Preview Audio plays one representative cycle using the current values.
- Preview and continuous playback remain separate engine actions.
- Dismissing Control Room stops any active preview.
- The title and accessibility labels use `Control Room`, not `Engine Room`.

Any internal instrument mode, ratio, sound profile, or synthesis parameters needed by the existing engine must remain hidden implementation details unless the user explicitly revalidates them later.

## Audio System Requirements

### Training Cycle

Each continuous cycle is:

1. **Build-up / rhythm lock-in**
   - Establishes calm timing before motion.
   - Gives the user time to settle rather than react.
2. **Launch cue**
   - Clearly signals when the swing begins.
   - Must be distinct without feeling like an alarm.
3. **Guided swing-duration cue**
   - Stretches across the intended swing motion.
   - Supports a smooth takeaway and cleaner transition.
   - Must feel cinematic and restrained, not sci-fi or novelty-driven.
4. **Reset space**
   - Provides deliberate silence or near-silence before the next rep.
   - Duration is controlled by `Break Between Swings`.

### Two-Layer Contract

#### Metronome Layer

- Provides precise timing structure.
- Establishes repeatable spacing.
- Sits behind the training experience rather than becoming the product identity.
- Uses restrained, premium transients.

#### Swing-Duration Cue Layer

- Guides the motion as one connected swing.
- Makes the transition perceptible without voice instruction.
- Must remain synchronized with the metronome layer.
- Must not become a collection of unrelated sound effects.

### One Timing Source

- Audio and visuals must derive from the same cycle configuration.
- Preview and continuous playback must use the same timing and synthesis behavior.
- Control changes must not create a second timer or parallel timing engine.
- Visual timing must not be driven by an independent approximation that can drift from audio.

### Preview Contract

Preview Audio:

- plays one complete `build -> launch -> guided swing -> reset` example
- uses current tempo speed and break value
- never overlaps a previous preview
- never starts the continuous loop
- stops cleanly when Control Room closes

### Audio Quality Bar

The audio should feel:

- cinematic
- calm
- precise
- tactile
- athletic
- repeatable

The audio must not feel:

- cheesy
- voice-coached
- bland metronome-only
- gimmicky sci-fi
- random
- toy-like

### Audio Acceptance Gate

The pass fails if:

- the metronome and swing-duration cue feel unrelated
- the launch point is ambiguous
- the transition still encourages rushing
- break time does not create meaningful reset space
- Preview differs materially from the live loop
- the user must watch the screen to understand the rhythm

## Visual Model

### Role Of The Screen

The screen supports the sound. It does not lead the practice session.

### Ready Visual

- Show one calm representation of the loaded tempo.
- Keep Start visually dominant.
- Avoid a carousel or selector disguised as the main instrument.

### Running Visual

Use one of these restrained directions:

- a pulsating orb that grows through build, resolves at swing, and settles during reset
- a bright point moving across a simple arc with restrained phase emphasis

Required behavior:

- readable through peripheral vision
- synchronized to the audio cycle
- reduced-motion compatible
- dark, layered, and premium
- minimal text

Avoid:

- dense landmark labels
- equal visual emphasis on every subdivision
- decorative motion unrelated to sound
- permanent neon flooding
- metrics that imply the user should monitor the phone

## Control Hierarchy

### Primary

- personal saved tempo
- Start / Stop

### Secondary

- Control Room
- Swing Capture

### Tertiary Or Hidden

- technical audio parameters
- internal timing ratios
- synthesis profile details

### Removed From User Choice

- club-based setup
- instrument mode
- swing shape
- sound skin

## Copy And Language Cleanup

| Current Or Risky Language | Replacement | Reason |
| --- | --- | --- |
| `Engine Room` | `Control Room` | Practical, premium, and intentional. |
| `Instrument setup` | `Tune your rhythm` or remove | The user is training, not configuring an instrument. |
| `Metronome` / `Build` mode selector | Remove | The two layers should work together as one product. |
| `Start Metronome` / `Start Build` | `Start` | One clear action for one trusted rhythm. |
| `Swing Shape` | Remove from visible controls | The user chose one tempo identity, not shape presets. |
| `Athletic / Balanced / Stretched` | Remove from primary experience | These are still preset choices and dilute recall. |
| `2.5:1 / 3:1 / 4:1` | Internal implementation detail | Ratio math is not the product promise. |
| `Click Voice` / `Build Voice` | Remove from visible controls | Avoid soundboard behavior. |
| `Sound Skin` | `Audio` only when a label is required | Plain language is clearer. |
| `Preview [Instrument]` | `Preview Audio` | Describes the action directly. |
| `Break Between Swings` | Keep | Clear, user-approved training language. |
| `READY / LIVE` | Optional; prefer `Ready / Running` | Avoid unnecessary HUD language. |
| `LOAD`, `controlled pressure`, `strict click count` | Revalidate against `Build / Swing / Reset` | Current labels expose mode-specific concepts. |

## Personal Tempo Recall And Persistence Decision

The product direction requires:

- one personal default tempo
- trusted setup already loaded on entry

The current routed implementation initializes Tempo Builder with local in-memory defaults. No persistence change is allowed in this spec pass.

Before implementing recall, choose the smallest approved storage approach:

1. Reuse an existing Garage-local settings mechanism if one already exists at implementation time.
2. Otherwise use a narrow non-SwiftData preference for the tempo value and break duration, if architecture review approves it.
3. Do not add or migrate SwiftData models solely for Tempo Builder recall without explicit approval.

Until recall storage is approved, implementation may simplify the flow and use a stable default, but it must not falsely claim that a personal tempo was saved.

## Implementation Phases

### Phase 1 - Product Clarification Spec

Deliverable:

- this document

Acceptance:

- direction is explicit
- removals are explicit
- no implementation files change

### Phase 2 - Language And Flow Cleanup

Primary files:

- `GarageHomeTabView.swift`
- `HorizonVaultDialView.swift`
- `EngineRoomSettingsView.swift`

Work:

- rename Engine Room to Control Room
- make Start generic and dominant
- remove club/preset implications from Garage Home Tempo preview
- remove fake-clever and mode-specific copy
- preserve routing and current local state

Acceptance:

- user can explain the feature as one anti-rush rhythm trainer
- no club-tempo language remains in the Tempo Builder entry or live surface

### Phase 3 - Control Room Simplification

Primary files:

- `EngineRoomSettingsView.swift`
- `HorizonVaultDialView.swift`

Work:

- expose only tempo speed, break between swings, and Preview Audio
- remove visible instrument, swing-shape, and sound-skin controls
- keep preview and live-loop paths separate
- decide whether hidden engine defaults remain temporarily

Acceptance:

- Control Room contains exactly the three approved controls
- no migration or cross-module state is introduced

### Phase 4 - Audio Experience Upgrade

Primary files:

- `ElasticSlingshotAudioEngine.swift`
- `HorizonVaultDialView.swift`
- focused Garage audio tests where feasible

Work:

- combine metronome timing and guided swing-duration cue into one coherent cycle
- define build-up, launch, guided swing, and reset clearly
- preserve generated real-time DSP and one timing source
- make Preview representative of live continuous playback

Acceptance:

- the cue audibly discourages a rushed takeaway and skipped transition
- Preview and live loop match
- changes to tempo and break are immediately perceptible
- no system sounds, bundled samples, or third-party audio libraries are introduced

### Phase 5 - Running Screen Refinement

Primary file:

- `HorizonVaultDialView.swift`

Work:

- replace attention-heavy running presentation with one peripheral visual
- minimize labels and controls
- lock visual progress to the same cycle state as audio
- preserve reduced-motion behavior

Acceptance:

- the user can practice without watching the phone
- a peripheral glance still communicates build, swing, and reset
- visuals feel restrained and premium

### Phase 6 - Personal Tempo Recall

Primary files:

- to be selected after storage decision

Work:

- load the trusted personal tempo on entry
- persist only the approved minimal settings
- keep Garage ownership and local-first behavior

Acceptance:

- reopening Tempo Builder restores the approved personal setup
- no SwiftData migration occurs unless separately approved
- UI never claims a value is saved unless it is actually recalled

## Implementation Boundaries

Allowed:

- Garage-local copy and hierarchy changes
- Garage-local view simplification
- existing real-time DSP refinement
- existing preview/live playback separation
- local non-network settings recall after explicit storage approval

Not allowed:

- changes outside Garage
- shell or routing redesign
- routing through legacy Tempo Builder UI
- club presets or club-specific tempo logic
- SwiftData migration without explicit approval
- AI coaching
- heavy diagnostics
- third-party libraries
- prerecorded or system-alert audio replacing the generated engine

## QA Checklist

### Product And Flow

- [ ] Garage Home presents Tempo Builder as one personal rhythm trainer.
- [ ] No Driver / irons / wedges / putting tempo preset language remains.
- [ ] Ready state opens with one trusted setup.
- [ ] Start is the obvious primary action.
- [ ] Running state loops continuously until stopped.
- [ ] Control Room is reachable without turning the main screen into settings.

### Control Room

- [ ] Title is `Control Room`.
- [ ] Visible controls are limited to Tempo Speed, Break Between Swings, and Preview Audio.
- [ ] No instrument mode selector is visible.
- [ ] No swing-shape or ratio selector is visible.
- [ ] No sound-skin browser is visible.
- [ ] Preview plays one cycle and does not overlap itself.

### Audio

- [ ] Metronome layer provides precise structure.
- [ ] Swing-duration cue feels connected to the metronome layer.
- [ ] Build-up creates calm before the swing.
- [ ] Launch cue is clear but restrained.
- [ ] Guided cue discourages a rushed takeaway and transition.
- [ ] Break Between Swings produces meaningful reset space.
- [ ] Preview matches continuous-loop timing and character.
- [ ] Audio remains generated through the existing real-time engine path.
- [ ] Swing Capture coexistence is preserved.

### Visual

- [ ] Running visual is understandable through peripheral vision.
- [ ] Visual timing is derived from the same cycle state as audio.
- [ ] Running state has minimal text and no dense metrics.
- [ ] Stop remains obvious.
- [ ] Reduced Motion preserves phase clarity.
- [ ] The screen remains premium, dark, restrained, and tactile.

### Architecture And Regression

- [ ] Live route remains `GarageView -> .tempoBuilder -> GarageTempoBuilderView`.
- [ ] Garage module boundaries remain intact.
- [ ] No unrelated modules change.
- [ ] No third-party dependency is added.
- [ ] No SwiftData migration occurs without approval.
- [ ] Existing Swing Capture behavior remains local and functional.
- [ ] Focused parse/build verification passes.
- [ ] Runtime audio is listened to on a suitable device before declaring the audio phase complete.

## Open Questions

1. What exact value does `Tempo Speed` control in the final product: anchor BPM, total swing duration, or a beginner-readable slower/faster scale backed by BPM?
2. Which minimal local storage mechanism should own the personal default tempo and break duration?
3. Should the guided swing cue include a brief transition shelf, or should transition clarity come entirely from the relationship between the metronome layer and swing-duration cue?
4. Should Control Room changes update a running loop immediately, or require stopping first for a calmer interaction model?
5. Should Swing Capture remain accessible while running, given that the user is expected to put the phone down?
6. Which peripheral visual direction should be validated first: pulsating orb or traveling arc light?
7. Should the existing internal sound profile remain fixed to one curated baseline, or should audio character become a later hidden accessibility/preference option?

## Final Acceptance Standard

Tempo Builder is successful when the user can open one trusted tempo, press Start, look away from the phone, hear a calm build into a guided swing, reset, and repeat without navigating presets or decoding technical labels.

The result should feel like a personal rhythm instrument, not a collection of tempo features.
