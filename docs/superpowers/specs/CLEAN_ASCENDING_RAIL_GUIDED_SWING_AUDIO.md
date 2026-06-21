# Clean Ascending Rail Guided Swing Audio

- Status: implementation baseline; physical-device listening approval pending
- Date: 2026-06-21
- Scope: Garage Tempo Builder Guided Swing audio only

## Direction

Clean Ascending Rail is a memorable tonal tempo guide, not simulated golf-impact physics. One warm sine-led voice rises smoothly from roughly 260 Hz to 520 Hz through the backswing. A true silent top hold separates that rise from a compact, brighter downswing and impact resolution from the same harmonic family.

The default 60 BPM Tour schedule remains two seconds long: approximately 1.5 seconds of backswing, 160 milliseconds of silence, then the existing downswing-to-impact boundary. Count-in, rest, haptics, next-full-swing-boundary BPM application, and Metronome behavior remain owned by the existing session and timing systems.

## Rejection Rules

Do not add clacks, thumps, snaps, metal, stone, leather, rubber, carbon, tool strikes, crash layers, arcade chirps, notification markers, noisy whooshes, or assembled SFX collages. Do not fill the top pause. Do not add background Guided Swing clicks. Do not reuse this profile as a reason to alter Metronome.

The tonal rise must stay warm, steady, learnable, and controlled on an iPhone speaker. Shimmer may only be a restrained harmonic component. Peaks must remain below the engine limiter ceiling and must not depend on clipping for perceived strength.

## App-Facing Profile Policy

Clean Ascending Rail is the only preferred Guided Swing profile. Power Tour, Heavy Coil, and Whip Line remain legacy/internal definitions so existing saved values continue to load safely, but migration resolves them to Clean Ascending Rail. The persistence key `garage.tempoBuilder.guidedSound` is unchanged.

## Acceptance

- The backswing is clearly audible and rises continuously.
- The top interval renders digital silence.
- Downswing and impact are audible, short, and distinct from the sustained build.
- Generated samples remain below the limiter ceiling.
- The complete phrase is approved by listening on a physical iPhone speaker.

The final item cannot be proven by static checks or automated tests.
