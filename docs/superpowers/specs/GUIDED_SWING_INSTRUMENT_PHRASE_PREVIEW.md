# Guided Swing Instrument Phrase Preview

- Status: preview architecture implemented; approved source assets required
- Date: 2026-06-21
- Scope: DEBUG-only physical-iPhone listening index
- App integration: none

## Decision

The sustained oscillator rail is rejected because continuous sine/triangle-led motion reads as a synthetic hum on an iPhone speaker. The physical-material direction is also rejected: raw leather, steel, stone, rubber, wood, thumps, clacks, snaps, and collages sound noisy and cheap under repetition.

Guided Swing should pivot to short, discrete, sample-backed instrument or luxury UI events. Muted Rhodes is the preferred first candidate, followed by felt piano, soft rosewood marimba, muted nylon guitar, and luxury UI chime. Human rhythm remains spec-only until clean legal voice material exists.

Guided Swing audio should not imitate a golf swing. It should make the golfer move correctly:

- **Load:** calm, unhurried, controlled.
- **Top:** patience, not panic.
- **Release:** decisive but not violent.
- **Impact:** resolved, clean, complete.

The emotional target is: “I know when to move, I trust the rhythm, and I can repeat this without irritation.”

## Shared Phrase

- Three short ascending events at 0.00, 0.58, and 1.16 seconds.
- Backswing phrase ends at approximately 1.74 seconds.
- True digital silence from 1.74 to 1.90 seconds.
- One compact impact confirmation at 1.90 seconds.
- Short tails, conservative loudness, and no time-stretching.

The preview player schedules discrete source files. It does not synthesize missing sounds, stretch a long sample, or route through the live `ElasticSlingshotAudioEngine`.

## Candidate Direction

1. **Muted Rhodes — primary:** A3 → C4 → D4, then muted A3/D4 confirmation. Keep notes at 260–420 ms and confirmation at 180–300 ms. Reject lounge-bar cheese, cheap keyboard tone, wide chorus, heavy reverb, and synthetic pad character.
2. **Felt Piano — secondary:** G3 → B3 → D4, then damped G3/D4 confirmation. Keep notes at 220–360 ms. Reject trailer piano, bright plink, music-box tone, cinematic bass, and prestige-drama sadness.
3. **Soft Rosewood Marimba — secondary:** A3 → C4 → E4, then muted A3 confirmation. Keep notes at 180–280 ms and use E4 only when warm and rounded. Reject toy xylophone, playful bounce, bright clack, and cartoon bonk.
4. **Muted Nylon Guitar — exploratory:** E3 → G3 → B3, then muted E3/B3 double-stop. Keep notes at 180–320 ms. Reject strums, spa drift, campfire mood, sleepy pacing, and finger squeak.
5. **Luxury UI Chime — exploratory:** C4 → E4 → G4, then soft lower C4 confirmation. Keep events at 120–220 ms and use G4 only when dark and damped. Reject notifications, alarms, medical-device sterility, pings, and piercing overtones.
6. **Human Rhythm:** Spec-only coach cadence. Do not record or generate speech without clean project-owned or approved source material.

Do not build five complete sound systems before proving one lane. Source and test Muted Rhodes first, Felt Piano second, and Rosewood Marimba third. Keep Nylon Guitar and Luxury UI Chime available only as lower-priority exploration.

## Asset And License Gate

The repository currently has no suitable instrument samples. Existing CC0 percussion recordings and project-generated physical identity files belong to rejected sound families. No candidate becomes playable until all four required WAVs are present and every source has a truthful entry in `GUIDED_SWING_INSTRUMENT_SOURCE_MANIFEST.json` with author/library, original URL, license, edits, and phrase role.

Audio should be mono PCM at 44.1 or 48 kHz, peak-safe, tightly trimmed, and mastered for repeated iPhone-speaker listening. Missing files must remain visibly unavailable; there is no procedural fallback.

## Rejection Rules

Reject continuous oscillator rails, drones, sweeps, beeps, chirps, high pings, raw foley, material collages, harsh shimmer, clicky top markers, noisy whooshes, tool-hit impacts, long reverb, clipping, upper-mid fatigue, bass mud, lounge music, spa drift, notification energy, toy character, and any “why is my phone doing that?” or punt-phone response.

## Listening And Selection

Use the same physical iPhone, volume, and room for the first comparison. Optionally repeat the winner outside or in a noisier space. Test each playable candidate for exactly ten fake swings; do not judge after one swing unless it is instantly offensive.

Score only:

1. Pleasantness after ten swings.
2. Clarity of timing.
3. Whether the silent pause feels intentional.
4. Whether impact feels like resolution.
5. Whether the sound remains acceptable for five minutes of practice.

Apply these decision rules:

- Pleasant but unclear: adjust event spacing.
- Clear but annoying: reject the timbre.
- Premium but too musical: shorten decay and remove reverb.
- Athletic but cheap: soften attack and lower the register.
- Nothing survives ten swings: reject the sound family rather than endlessly remixing it.

## Final Product Shape

Do not turn Guided Swing into a “choose your instrument” toy. Ship one default sound identity. Add at most one alternate only if physical listening proves it serves a genuinely different training need. Human rhythm coaching may become a separate training mode later; it does not belong in the initial sound picker.

## Approval Gate

Use launch argument `GUIDED_SWING_INSTRUMENT_PREVIEW` in a DEBUG build to open the isolated index. The user must compare candidates on a physical iPhone and repeat each at least ten times. A winner may enter live Guided Swing only after it is pleasant, clear, and non-fatiguing on device. Preview approval does not authorize changes to live routing, persistence, count-in, BPM handling, haptics, Metronome, or session behavior.
