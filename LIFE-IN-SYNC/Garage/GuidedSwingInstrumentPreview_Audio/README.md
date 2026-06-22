# Muted Rhodes Timing Cue Preview Assets

This DEBUG-only audition lane intentionally contains no audio. The user must manually source four legally usable, short, dry WAV files:

- `backswing_01.wav`
- `backswing_02.wav`
- `backswing_03.wav`
- `impact_confirm.wav`

Use mono PCM at 44.1 or 48 kHz with conservative peaks and tightly trimmed tails. The preview schedules the backswing cues at 0.00, 0.58, and 1.16 seconds, stops lingering playback at 1.74 seconds, preserves 160 milliseconds of silence, and starts the impact confirmation at 1.90 seconds.

Before adding any WAV, record its actual source, author or library, original URL, license, required attribution, edits, and phrase role in `GUIDED_SWING_INSTRUMENT_SOURCE_MANIFEST.json`. Do not add files with unclear provenance.

Missing or unreadable files keep Preview disabled. There is no oscillator, generated, live-engine, or other audio fallback. This lane does not replace live Guided Swing.
