# Guided Swing Premium Lift Hill Approved Baseline

**Date approved:** 2026-06-22

**Status:** Listening-approved baseline; production asset completion pending

**Design authority:** `docs/superpowers/specs/2026-06-22-guided-swing-premium-lift-hill-design.md`

**Implementation authority:** `docs/superpowers/plans/2026-06-22-guided-swing-premium-lift-hill-implementation-plan.md`

## Baseline Artifact

External artifact:

`/Users/colton/Desktop/LIFE-IN-SYNC Guided Swing Audio QA/Approved Baseline/guided_swing_premium_lift_hill_baseline.wav`

SHA-256:

`15627da23d7ba37c711921e7bd837fb57075565895ff6cc42f433960b464e4d1`

The checksum is the authority for the listening-approved Candidate 03 composite. The external file is not a production bundle asset because two supporting sources remain preview quality.

## Approved Audio Contract

At 60 BPM:

1. The exact user-selected `171510__esperar__rollercoaster-ratchet.wav` source fills 0.000-1.500 seconds without pitch shifting.
2. Restrained open-air height supports the lift without becoming a whoosh.
3. A slight exhale occupies 1.500-1.660 seconds.
4. The downswing is digitally silent from 1.660-2.000 seconds.
5. The user-selected `816986__luisa_sanchez__golf-swing.wav` begins at impact; its measured composite peak occurs at 2.006644 seconds.
6. Composite peak is 0.88 with no additional impact layer.

The live `GarageGuidedSwingCycleSchedule` remains the timing authority at other BPM values.

## Baseline Protection

- Never overwrite the approved baseline artifact.
- Create every future experiment in a new candidate folder with a new filename.
- Compare future candidates directly against this baseline at matched playback level and timing.
- Promote a replacement only after explicit listening approval.
- If a change is merely different or introduces a regression, retain the baseline.
- Preserve the exact silent-downswing and sole-impact-source contracts unless the user explicitly changes them.

## Production Readiness

Approved original-quality sources:

- `171510__esperar__rollercoaster-ratchet.wav` — esperar — CC0 — mono 44.1 kHz, 16-bit WAV.
- `816986__luisa_sanchez__golf-swing.wav` — Luisa_Sanchez — CC0 — mono 44.1 kHz, 24-bit WAV.

Still required before live integration:

- original-quality licensed WAV for the restrained open-air wind;
- original-quality licensed WAV for the slight exhale.

Preview MP3s must not be added to the app bundle or treated as production masters. Original replacements must preserve the approved character and pass direct A/B listening against this baseline.

## Expansion Policy

Expansion means improving source fidelity, mastering, tempo scaling, and production integration while preserving the approved identity. It does not mean adding a player-facing novelty library or reopening rejected piano, synthetic rail, zippy downswing, or cartoon-impact directions.
