# Guided Swing Instrument Phrase Preview Assets

This folder intentionally contains no audio yet. The existing repository assets do not provide clean, license-documented Rhodes, felt piano, rosewood marimba, nylon guitar, or premium UI-instrument sources.

Each playable candidate requires four mono WAV files. These names are the runtime contract:

- Muted Rhodes: `muted_rhodes_01_A3.wav`, `muted_rhodes_02_C4.wav`, `muted_rhodes_03_D4.wav`, `muted_rhodes_impact_A3_D4.wav`
- Felt Piano: `felt_piano_01_G3.wav`, `felt_piano_02_B3.wav`, `felt_piano_03_D4.wav`, `felt_piano_impact_G3_D4.wav`
- Rosewood Marimba: `rosewood_marimba_01_A3.wav`, `rosewood_marimba_02_C4.wav`, `rosewood_marimba_03_E4.wav`, `rosewood_marimba_impact_A3.wav`
- Nylon Guitar: `nylon_guitar_01_E3.wav`, `nylon_guitar_02_G3.wav`, `nylon_guitar_03_B3.wav`, `nylon_guitar_impact_E3_B3.wav`
- Luxury UI Chime: `luxury_ui_chime_01_C4.wav`, `luxury_ui_chime_02_E4.wav`, `luxury_ui_chime_03_G4.wav`, `luxury_ui_chime_impact_C4.wav`

Source in this order: Muted Rhodes first, Felt Piano second, and Rosewood Marimba third. Nylon Guitar and Luxury UI Chime remain exploratory. Human Rhythm is spec-only and requires no files.

Use 44.1 kHz or 48 kHz PCM, short clean tails, conservative peaks, and no baked-in timing gaps. The preview player places the events at 0.00, 0.58, 1.16, and 1.90 seconds, leaving 160 milliseconds of true silence after the 1.74-second backswing window.

Before adding a WAV, add its real source, author/library, license, original URL, edits, and role to `GUIDED_SWING_INSTRUMENT_SOURCE_MANIFEST.json`. The unique filename prevents a bundle-resource collision with the live Metronome manifest. Do not use a file with unclear provenance. Do not substitute an oscillator mock and relabel it as an instrument recording.
