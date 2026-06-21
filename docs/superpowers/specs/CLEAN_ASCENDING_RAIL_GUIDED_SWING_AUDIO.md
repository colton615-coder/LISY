# Clean Ascending Rail Guided Swing Audio

- Status: warm/low timbre tuning implemented; ten-swing physical-device approval pending
- Date: 2026-06-21
- Scope: Garage Tempo Builder Guided Swing audio only

## Direction

Clean Ascending Rail is a memorable tonal tempo guide, not simulated golf-impact physics. Physical iPhone listening rejected the original 260–520 Hz sine-led version as high, tight, nasal, and fatiguing. That version remains only as a saved-value compatibility reference.

The preferred Warm tuning rises from approximately 180–360 Hz. The QA-only Low alternative rises from approximately 140–280 Hz. Both use a soft triangle-led body, quiet sine support, and subtle half-frequency body with no octave shimmer or saturation. A true silent top hold separates the rise from a compact muted confirmation in the same sound family.

The default 60 BPM Tour schedule remains two seconds long: approximately 1.5 seconds of backswing, 160 milliseconds of silence, then the existing downswing-to-impact boundary. Count-in, rest, haptics, next-full-swing-boundary BPM application, and Metronome behavior remain owned by the existing session and timing systems.

## Rejection Rules

Do not add clacks, thumps, snaps, metal, stone, leather, rubber, carbon, tool strikes, crash layers, arcade chirps, notification markers, noisy whooshes, or assembled SFX collages. Do not fill the top pause. Do not add background Guided Swing clicks. Do not reuse this profile as a reason to alter Metronome.

The tonal rise must stay warm, steady, learnable, and controlled on an iPhone speaker. Do not add octave shimmer, sharp upper harmonics, resonant brightness, or saturation to manufacture presence. Peaks must remain below the engine limiter ceiling and must not depend on clipping for perceived strength.

## App-Facing Profile Policy

Clean Ascending Rail Warm is the only preferred app-facing Guided Swing profile. The DEBUG audio QA surface exposes exactly two choices: Clean Ascending Rail Warm and Clean Ascending Rail Low. The original Clean Ascending Rail value plus Power Tour, Heavy Coil, and Whip Line remain legacy/internal definitions; migration resolves old values to Warm. The persistence key `garage.tempoBuilder.guidedSound` is unchanged.

## Acceptance

- The backswing is clearly audible and rises continuously.
- The top interval renders digital silence.
- Downswing and impact are audible, short, and distinct from the sustained build.
- Generated samples remain below the limiter ceiling.
- The complete phrase is approved by listening on a physical iPhone speaker.
- Ten consecutive swings do not create irritation or ear fatigue.

The final item cannot be proven by static checks or automated tests.
