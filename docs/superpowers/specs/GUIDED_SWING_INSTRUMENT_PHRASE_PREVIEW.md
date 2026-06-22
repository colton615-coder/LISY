# Muted Rhodes Timing Cue Preview

- Status: DEBUG-only sample audition lane
- Owner: `GarageTempoAudioQAView`
- Live integration: none

## Decision

The only active sample-preview direction is `Muted Rhodes Timing Cue`. It uses four manually sourced WAV files: `backswing_01`, `backswing_02`, `backswing_03`, and `impact_confirm`.

The preview schedules short backswing cues at 0.00, 0.58, and 1.16 seconds. It stops lingering backswing playback at 1.74 seconds, leaves 160 milliseconds of silence, and starts the compact impact confirmation at 1.90 seconds. `AVAudioPlayer` scheduling is suitable for auditioning only and is not claimed to be sample-accurate production timing.

## Asset Gate

The user must manually source legally usable WAV files. Each source requires truthful provenance in `GUIDED_SWING_INSTRUMENT_SOURCE_MANIFEST.json`, including the source library, URL, author, license, attribution requirement, edits, and phrase role.

Preview remains disabled until all four files are present and decode successfully. Missing or unreadable files never fall back to oscillators, generated audio, the live Guided Swing engine, or another sample.

## Boundaries

This lane exists only inside the DEBUG Tempo Audio QA screen. It does not replace or modify live Guided Swing playback, Metronome behavior, routing, persistence, count-in, BPM-boundary application, haptics, or session timing.
