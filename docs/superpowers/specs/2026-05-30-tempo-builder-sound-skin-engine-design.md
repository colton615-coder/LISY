# Tempo Builder Sound-Skin Engine Design

- Status: in review
- Scope: Garage module only
- Date: 2026-05-30
- Owner surface: Tempo Builder

## Verdict

Build Tempo Builder around one stable timing and fine-tuning engine with multiple premium sound skins.

The rebuild must fix the current audio feel without changing the user's tempo math. Sound packs are sonic materials layered over the same swing cycle, not separate engines, modes, or training rules.

## Discovery Summary

User direction:

- Overall direction: premium instrument.
- Feel target: elastic and athletic, blended with calm and meditative.
- Downswing: subtle release trail.
- Impact: bright snap.
- Sound model: one timing system and one fine-tuning model, with different types of sounds.
- Sound examples: balloon-like, kazoo/reed-like, thunderous, rubber-band-like.
- Naming: serious training-pack language, not toy labels.
- Initial count: 8 sound packs.
- Shape: every pack uses the full swing audio shape.
- Cockpit behavior: current pack visible, full selection in a compact one-tap sheet.
- Preview behavior: no autoplay while browsing; explicit play action only.
- Pack description: one short plain-English feel line.
- Success priority: coachable, then premium, then fun.

## Product Contract

Tempo Builder is a Garage-local rhythm rehearsal service. It is not a generic metronome, soundboard, swing analyzer, or real-time coaching surface.

The user should be able to rehearse tempo without staring at the screen. Audio must make the swing shape legible:

1. Takeaway load
2. Top tension
3. Soft downswing trail
4. Bright impact snap

The sound should feel like an instrument built for golf practice: coachable first, expensive second, and enjoyable third.

## Timing Contract

Tempo logic is shared by every pack:

- BPM remains the source of rhythm speed.
- Tempo ratio remains the source of phase duration.
- Pause/top timing remains shared.
- Setup delay remains shared.
- Loop/rest timing remains shared.
- Fine-tuning controls affect timing consistently across packs.
- Pack changes must not alter tempo math.

Changing sound pack may change timbre, envelope, harmonic content, noise texture, transient color, and perceived physicality. It must not change when address, top, release, or impact happen.

## Sound-Pack Contract

Ship 8 serious training packs:

| Pack | Feel line |
| --- | --- |
| Elastic | Smooth stretch, calm release, sharp snap. |
| Storm | Low pressure build, thunder body, bright strike. |
| Airframe | Breathy lift, clean trail, crisp snap. |
| Reed | Controlled reed texture with playful edge. |
| Pulse | Modern rhythm pressure with surgical impact. |
| Gravity | Deep load, soft fall, bright strike. |
| Glass | Clean shimmer, tight top, precise snap. |
| Rubber | Elastic training feel without toy energy. |

Every pack must implement the same phase shape:

- Takeaway load: audible enough to coach rhythm, not loud enough to dominate.
- Top tension: a clear sense of arrival or held pressure.
- Downswing trail: soft release trail, never a cheap buzz, muddy drone, or goofy low-end wobble.
- Impact snap: bright, crisp, satisfying, and short.

## UI Contract

The cockpit should treat pack selection as part of the instrument without cluttering active practice.

Required behavior:

- Show the selected pack in the main Tempo Builder cockpit.
- Open all packs from a compact one-tap selector sheet.
- Do not autoplay when a user taps around the sheet.
- Provide an explicit preview button per pack or for the selected pack.
- Use pack name plus one short feel line.
- Keep BPM, ratio, pause, and fine-tuning controls visually more important than novelty sound browsing.

## Architecture Boundaries

Allowed:

- Garage-local enum or value type for sound packs.
- Garage-local sound rendering changes.
- Garage-local selector UI.
- In-memory pack selection if persistence is not explicitly approved.
- Existing `AVAudioEngine` / local synthesis path.

Not allowed without separate approval:

- SwiftData schema migration.
- Persisted sound-pack preferences.
- New third-party audio dependencies.
- Network audio generation.
- AI-generated sounds.
- Routing changes outside Garage.
- Changes to Drill Plans, Journal, Vault, or Focus Room.

## Failure Handling

The audio system should fail quietly and preserve practice flow:

- If audio engine startup fails, Tempo Builder remains usable visually.
- Preview failure must not change selected pack.
- Pack selection must always have a valid fallback.
- Missing pack metadata falls back to the default pack.

## Non-Goals

This spec does not include:

- Swing video capture changes.
- Tempo history or saved sessions.
- AI coaching.
- Haptic redesign.
- Per-pack tempo math.
- User-authored custom sound design.
- A soundboard mode.
- SwiftData migrations.

## Acceptance Criteria

- Documentation and implementation agree that Tempo Builder uses one timing/fine-tuning engine.
- Eight serious sound packs are represented with plain-English feel lines.
- Every pack uses the same full swing phase shape.
- Sound selection is accessible from the cockpit through a compact sheet.
- Sound browsing requires explicit preview action, not autoplay.
- The audio direction prioritizes coachable, premium, then fun.
- No persistence, routing, or unrelated Garage surface changes are required for V1.
