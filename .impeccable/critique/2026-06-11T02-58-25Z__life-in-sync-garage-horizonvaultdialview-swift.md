---
target: Tempo Builder
total_score: 25
p0_count: 0
p1_count: 2
timestamp: 2026-06-11T02-58-25Z
slug: life-in-sync-garage-horizonvaultdialview-swift
---
## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Ready state is visible, but the tiny pendulum and sound controls compete with it. |
| 2 | Match System / Real World | 2 | The current pendulum reads as a hanging marker, not a premium metronome instrument. |
| 3 | User Control and Freedom | 3 | BPM, sound, preview, haptics, and Start are available, but the hierarchy is weak. |
| 4 | Consistency and Standards | 3 | Native controls and shared Garage styling are present. |
| 5 | Error Prevention | 3 | Disabled states and playback guards exist. |
| 6 | Recognition Rather Than Recall | 3 | Labels are visible, but the unlabeled dark circular sound control is ambiguous. |
| 7 | Flexibility and Efficiency | 3 | BPM step controls and slider are efficient. |
| 8 | Aesthetic and Minimalist Design | 1 | The screen lacks one commanding practice focal point and feels unfinished. |
| 9 | Error Recovery | 2 | No visible recovery state was observed in the ready-state recording. |
| 10 | Help and Documentation | 2 | The interface provides little explanation of the instrument or secondary controls. |
| **Total** | | **25/40** | **Functional, visually unresolved** |

## Anti-Patterns Verdict

**LLM assessment:** The current screen does not look like generic card-grid AI slop, but it does look like an unfinished AI-generated approximation of a metronome. The oversized empty center, tiny decorative pendulum, floating labels, and ambiguous sound controls lack the confidence of a finished instrument.

**Deterministic scan:** The Impeccable detector returned zero findings for `HorizonVaultDialView.swift`. This is a false-negative limitation: the detector is designed primarily for markup and cannot assess SwiftUI composition or the provided recording.

**Visual overlays:** No browser overlay was attempted because Tempo Builder is a native SwiftUI screen and project instructions prohibit simulator or visual QA runs unless explicitly requested.

## Overall Impression

The current implementation has the correct feature pieces but no dominant visual idea. The target screenshot solves that with a large recognizable physical metronome. The biggest opportunity is to make the instrument, not the settings, own the screen.

## What's Working

- BPM is immediately readable and has efficient step plus slider controls.
- The two-mode selector is understandable and supports the locked product structure.
- Emerald, white, and gold already align with Garage's premium palette.

## Priority Issues

### [P1] The metronome has no commanding focal instrument
**Why it matters:** The current small pendulum makes the screen feel empty and unfinished.  
**Fix:** Replace it with a large SwiftUI-drawn physical metronome occupying the central stage, using a trapezoidal body, tempo scale, arc ticks, gold pendulum arm, and restrained depth.  
**Suggested command:** `/impeccable bolder Tempo Builder metronome`

### [P1] Secondary controls dilute the practice hierarchy
**Why it matters:** The sound bar, preview, haptics, BPM controls, slider, mode selector, and Start button all compete instead of supporting one practice action.  
**Fix:** Follow the target hierarchy exactly: mode selector, BPM control, instrument stage, compact sound bar, fixed Start action. Remove inline sound cards and expanded library from the main screen.  
**Suggested command:** `/impeccable layout Tempo Builder`

### [P2] The current visual language lacks material credibility
**Why it matters:** Thin lines and floating circles do not communicate a premium physical training instrument.  
**Fix:** Use crisp SwiftUI shapes, tonal green layers, fine gold strokes, and limited shadows. Avoid reproducing the target screenshot's excessive glow and photorealistic noise.  
**Suggested command:** `/impeccable polish Tempo Builder`

### [P2] Ambiguous controls reduce trust
**Why it matters:** The dark circular control beside Bright Signal is not self-explanatory, and the target screenshot's `BEAT -1 / +1` labels are also unclear.  
**Fix:** Keep explicit sound, preview, and haptics affordances; omit `BEAT -1 / +1` unless they receive a real defined behavior.  
**Suggested command:** `/impeccable clarify Tempo Builder`

## Persona Red Flags

**Focused Golfer:** The current screen does not provide a strong visual beat anchor. Their eye moves between several small controls instead of settling on the practice instrument.

**First-Time User:** The small pendulum and ambiguous sound-row control do not clearly explain what will happen after Start.

**Accessibility User:** The target's detailed scale labels and low-contrast arc ticks would be difficult to read. The implementation should expose the instrument as one accessible status element and retain Reduce Motion behavior.

## Minor Observations

- The camera action remains visually equal to navigation despite being secondary.
- The target screenshot's large yellow Start button is effective but its glow should be reduced.
- The target's physical metronome can be recreated with SwiftUI shapes; a raster image would not adapt cleanly to state or device size.

## Questions to Consider

- Should the physical metronome be the Metronome-only signature while Guided Swing keeps its separate timing timeline?
- Does `BEAT -1 / +1` represent a real feature, or should it be removed?
- Should the sound row remain on the main screen despite the earlier direction to move tuning into Control Room?
