# Tempo Builder Guided Swing UI Redesign

- Status: approved design; implementation not started
- Scope: Garage Tempo Builder Guided Swing UI only
- Date: 2026-06-17
- Owner surface: `GarageTempoBuilderView` in `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
- Visual direction: LIFE-IN-SYNC interpretation of the supplied arc-first inspiration, not a literal reproduction

## Objective

Make Guided Swing feel like a focused premium training instrument. The connected swing arc becomes the visual hero, while BPM adjustment and Start remain obvious and usable during practice.

The redesign must preserve the newly unified Guided Swing timing source of truth. It changes presentation, not timing, audio behavior, persistence, navigation, or module architecture.

## Current System Observed

- `GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView()` is the live route.
- `HorizonVaultDialView.swift` owns the Tempo Builder shell, mode selector, Guided Swing page, arc presentation, tempo controls, session controls, and Control Room presentation.
- Guided Swing and Metronome retain separate saved BPM values.
- Tempo Builder currently opens on Metronome. This behavior remains unchanged.
- The Guided Swing arc consumes the shared cycle schedule and renderer-relative progress snapshot established by the P0 timing pass.
- Control Room and Swing Capture are secondary actions in the top bar.

## Locked Product Decisions

- Use the supplied screen as inspiration with LIFE-IN-SYNC restraint, not as an exact visual copy.
- Keep a subtle golfer silhouette inside the arc.
- Show a large BPM value with compact minus and plus controls plus a separate slider.
- Do not show a `Spoken: 3-2-1` selector on the main screen.
- Do not show a `Smooth & Balanced` or swing-feel row on the main screen.
- Keep Swing Capture as a restrained top-bar action.
- Keep the experience on one screen. Scale the arc and spacing for compact heights instead of introducing normal vertical scrolling.
- Keep Metronome as the default page when Tempo Builder opens.

## Visual Direction

The screen follows the LIFE-IN-SYNC `Focused Instrument` design principle:

- deep emerald-black background
- strong hierarchy with few surfaces
- warm gold reserved for the selected mode, active timing, and primary action
- restrained Sport-Tech energy in the arc
- no neon cockpit, gamer-dashboard treatment, or large decorative bloom
- no card pile or card-inside-card composition

The arc supplies the sport-tech expression. Typography, spacing, controls, and state feedback remain calm and Apple-native.

## Screen Hierarchy

From top to bottom:

1. compact Tempo Builder header
2. Metronome / Guided Swing mode selector
3. quiet session status
4. large Guided Swing arc hero
5. BPM adjustment row
6. Tempo slider panel
7. dominant session action

Control Room and Swing Capture remain in the header rather than becoming main-screen rows.

## Header

- Keep the centered `Tempo Builder` title.
- Keep Back on the leading side.
- Keep Control Room and Swing Capture as separate trailing icon buttons.
- Use at least 44-point touch targets.
- Keep secondary icons quieter than the title and primary Start action.
- Disable secondary actions while an active session requires the existing lockout behavior.

## Mode Selector

- Preserve the existing two-service selector and page-switch behavior.
- Keep `Metronome` and `Guided Swing` labels explicit.
- Selected Guided Swing uses a fine gold border and restrained emerald fill.
- Inactive Metronome remains readable but visually quiet.
- Do not change mode ordering, persistence, or the current Metronome-first opening behavior.

## Session Status

- Place one short state line between the mode selector and arc.
- Ready: `Ready to train`
- Counting in: retain the current count-in state and visible number treatment.
- Playing: use the existing phase-aware or build-to-impact status.
- Resting: preserve reset/rest feedback.
- Pending BPM: preserve `New tempo applies next swing.`
- Use semantic state plus text; do not rely on color alone.

## Guided Swing Arc Hero

### Composition

- Use a broad connected arch with Address on the lower left, Top at the apex, and Impact on the lower right.
- Backswing occupies the longer loading side; Downswing remains shorter and accelerates toward Impact.
- Keep Address, Top, and Impact as the explicit visible landmark labels.
- Phase status and marker movement communicate Backswing and Downswing without adding more permanent labels around the arc.
- Keep the active marker and trail synchronized to the existing shared cycle snapshot.

### Golfer Silhouette

- Use a code-native system symbol such as `figure.golf` where available.
- Render it as a low-opacity, noninteractive atmospheric layer centered inside the arc.
- It must never compete with the marker, labels, BPM, or Start action.
- Do not add a raster asset, package, downloaded illustration, or detailed animation.
- If the system symbol is visually unsuitable during implementation review, omit the silhouette rather than creating a bespoke decorative asset.

### Depth And Effects

- The inactive arc uses quiet emerald and mint depth.
- The active trail transitions toward warm gold approaching Impact.
- Limit glow to the active marker, short trail emphasis, and restrained Impact pulse.
- Optional faint interior guide arcs may establish depth at very low opacity, but they must not animate independently or resemble instrumentation data.
- Reduce Motion keeps exact landmark state changes and removes nonessential travel or pulse expansion.

### Timing Contract

- Do not introduce a second visual clock.
- Do not restore independent Core Animation cycle timing.
- Arc position, trail, labels, and Impact state continue consuming `GarageGuidedSwingCycleSchedule` and the token-matched cycle snapshot.
- UI layout changes must not alter Address, Top, Downswing, Impact, or completion boundaries.

## BPM Controls

### Primary BPM Row

- Show the saved Guided Swing BPM as the dominant numeric value using rounded system typography.
- Place compact minus and plus controls beside the value.
- Each control changes BPM by one within the existing `20...75` range.
- BPM remains locally persisted through the existing `garage.tempoBuilder.bpm` key.
- While playing, saved-versus-applied behavior remains unchanged: edits apply on the next full swing boundary.

### Tempo Slider Panel

- Keep one horizontal slider below the BPM row.
- Label it `TEMPO` with a quiet `20–75 BPM` range readback.
- Use one inset emerald surface with a fine border.
- Avoid additional nested capsules, dropdowns, or count-in controls inside this panel.
- Preserve native Slider accessibility and one-BPM stepping.

## Session Action

- Keep one full-width gold primary action above the bottom safe area.
- Ready title: `Start Guided Swing`.
- Preserve current active-session Restart and Stop behavior and state transitions.
- Do not change count-in, rest, pending BPM, haptic, or audio behavior in this UI pass.
- Use native pressed feedback and the existing restrained shadow vocabulary.

## Responsive Layout

- The normal layout must not scroll.
- Use available height to scale the arc and vertical spacing.
- Protect 44-point minimum touch targets and the primary action height.
- Prefer reducing decorative space, silhouette scale, and arc height before compressing controls.
- Use a compact one-screen variant for shorter devices or large text sizes.
- Preserve readable landmark labels and avoid truncating the BPM value.
- Extreme accessibility sizes may simplify decorative layers; the interaction order and accessible labels remain complete.

## Accessibility

- Preserve explicit accessibility labels and identifiers for Back, Control Room, Swing Capture, mode selection, BPM controls, slider, Start, Restart, and Stop.
- Combine the BPM value and unit into one meaningful accessibility element.
- Announce active mode and session state without exposing decorative layers.
- Hide the golfer silhouette and guide arcs from accessibility.
- Maintain sufficient contrast for inactive mode text and status copy.
- Respect Reduce Motion without reducing timing clarity.

## Architecture And Data Flow

- Keep the live route and `GarageTempoBuilderView` ownership unchanged.
- Keep the redesign within existing Garage-owned SwiftUI and UIKit-backed arc components.
- Recompose existing private subviews rather than creating a parallel Tempo Builder screen.
- Preserve `GarageTempoSessionController`, `GarageGuidedSwingCycleSchedule`, and renderer snapshot ownership.
- Preserve all existing `@AppStorage` keys.
- Do not introduce packages, new persistence, backend work, account work, or cross-module abstractions.

## Expected Files

Primary implementation file:

- `LIFE-IN-SYNC/Garage/HorizonVaultDialView.swift`
  - shell spacing
  - header presentation
  - Guided Swing composition
  - arc geometry and restrained decorative layers
  - BPM step controls and slider panel
  - primary action presentation
  - compact-height adaptation

Supporting file only if focused coverage requires it:

- `LIFE-IN-SYNCTests/GarageTempoBuilderTests.swift`
  - accessibility or stable UI-state contract coverage directly affected by changed view interfaces

Do not modify audio, session, persistence, navigation, Control Room layout, sound assets, or unrelated Garage files for this redesign.

## Risks

- A large arc can crowd compact-height devices if scaling is not based on available space.
- Excessive gold, shadow, or glow would turn the screen into a neon dashboard.
- The system golfer symbol may look generic or visually compete with the active marker.
- Replacing the arc renderer instead of reskinning it could accidentally weaken the P0 timing contract.
- Too many simultaneous BPM controls could feel redundant; visual hierarchy must make the large value primary and the slider secondary.

## Verification

Implementation verification should remain proportional to the UI-only scope:

- `xcrun swiftc -parse` for each changed Swift file
- `git diff --check`
- focused existing tests if affected
- no more than one full Xcode build, and only if focused parsing is insufficient
- simulator or visual QA only when explicitly requested

Runtime review should confirm:

- one-screen fit on compact and standard iPhone heights
- correct ready, count-in, playing, pending-tempo, resting, Restart, and Stop states
- arc marker and landmark visuals remain synchronized with the shared snapshot
- Metronome still opens first and remains visually/behaviorally unchanged
- Control Room and Swing Capture remain reachable
- Reduce Motion and accessibility remain usable

## Done Conditions

- Guided Swing visibly follows the approved arc-first hierarchy.
- The screen feels premium, calm, player-facing, and immediately usable during practice.
- The golfer silhouette is subtle and nonessential.
- BPM can be changed with minus, plus, or slider inside the existing range.
- No count-in selector or swing-feel row appears on the main screen.
- The Start action is dominant.
- The screen fits without normal scrolling.
- Existing timing, audio, haptics, persistence, navigation, Metronome behavior, Control Room layout, and module boundaries are preserved.
