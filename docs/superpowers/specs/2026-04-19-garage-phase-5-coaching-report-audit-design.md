# Garage Phase 5 Coaching Report Audit And Redesign Brief

Date: 2026-04-19
Module: Garage
Scope: `GarageCoachingReportView`, `GarageCoachingPresentation`, `GarageCoaching`, `GarageReliability`, `GarageInsights`
Source Screens:
- `/Users/colton/Downloads/garage coach1.png`
- `/Users/colton/Downloads/garagge coach 2.jpeg`

## Goal

Turn the current Garage coaching report into a production-grade coaching surface that is:
- visually premium and tactile
- semantically precise
- resilient across missing-data and low-confidence states
- simpler to maintain in SwiftUI

This brief audits both visible screenshots and the live code paths that power them.

## Recommended Direction

### Option 1. Recommended: Semantic State-Driven Coaching Surface
- Keep the current card stack shape.
- Replace string-driven presentation with typed view state.
- Separate `ready`, `review`, `unavailable`, and `provisional` into explicit render modes.
- Upgrade the visual system without changing Garage module boundaries.
- Best fit because it preserves current architecture while removing ambiguity and preview drift.

### Option 2. Visual-Only Polish Pass
- Keep the current adapter logic mostly intact.
- Improve spacing, contrast, badges, icons, and shadows only.
- Faster, but it leaves the state model muddy and keeps the current data-semantic mismatches alive.

### Option 3. Explainability-Heavy Coaching Console
- Expand the screen into a richer diagnostic console with metric provenance, check drill-downs, and issue evidence.
- Strongest for technical trust, but too large for a focused Phase 5 refactor.

## Recommended Execution Principle

Adopt Option 1. This keeps the screen familiar, gives the user a premium result fast, and fixes the current hidden architectural debt before it spreads.

## Current Runtime Pipeline

| Layer | Current Type | Purpose | Risk |
| --- | --- | --- | --- |
| Persistence | `SwingRecord` | Source of truth for frames, anchors, path, derived analysis | Strong |
| Analysis | `GarageInsights`, `GarageReliability`, `GarageCoaching` | Derives readiness, score, reliability, cues, blockers | Mostly strong |
| Presentation adapter | `GarageCoachingPresentation.make(...)` | Converts domain output into UI-friendly strings and tiles | Weakest seam |
| View | `GarageCoachingReportView` | Renders cards, badges, grids, and entrance animation | Visually solid, semantically under-typed |

## Key Architectural Findings

- `GarageCoachingPresentation` is doing real product logic, not just view formatting.
- `confidenceLabel` and `phaseLabel` are plain strings even though the app already has `GarageReliabilityStatus` and `SwingPhase`.
- `isUnavailable` is a derived boolean, but the actual fallback trigger is `report.cues.isEmpty`.
- The unavailable preview fixture does not match the live `metricTiles(...)` fallback path when `scorecard == nil`.
- `title` exists on `GarageCoachingPresentation` but is unused by the view.
- The view is read-only, but the UI styling makes some elements look tappable even though they have no gesture or state mutation.
- Progress bars always render a minimum width of `12`, which can visually exaggerate nearly-empty metrics.

## Hidden State Inventory

| Hidden State | Owner | Current Behavior | Redesign Direction |
| --- | --- | --- | --- |
| Shell entrance visibility | `@State isShellVisible` | Entire card stack fades, lifts, scales in | Keep, but centralize animation tokens |
| Per-section reveal | `@State visibleSections` | Hero, readout, signal mix, action reveal in sequence | Keep, but move into reusable `GarageStaggeredReveal` helper |
| Entrance identity cache | `@State lastAnimatedEntranceKey` | Prevents duplicate re-animation for same payload | Keep |
| Hero availability | `presentation.isUnavailable` plus `report.cues.isEmpty` | Removes glow and swaps copy to fallback | Replace with explicit mode enum |
| Session strip visibility | `presentation.snapshots.isEmpty == false` | Entire section disappears if empty | Keep, but define dedicated empty-state policy |
| Metric section visibility | `presentation.metrics.isEmpty == false` | Entire section disappears if empty | Keep, but show a semantic empty state in review/unavailable mode |
| Supporting line visibility | `supportingLine != nil` | Cyan bullet row appears only in ready states | Replace with typed disclaimer model |
| Notes block visibility | `presentation.notes.isEmpty == false` | Extra inset note tray appears only when blockers exist | Keep, but rename as `reviewNotes` or `trustNotes` |
| Capstone metric layout | odd metric count | Last metric becomes full-width | Strong pattern; preserve |

## Screenshot 1: Coaching Unavailable / Review / Impact

### Screen Intent

This is the low-trust coaching fallback surface. It tells the user:
- the system cannot yet produce a confident coaching cue
- some summary metrics are still available
- the next action is to repair review confidence before trusting coaching

### Component Audit

| Element | Operational Logic And Data Contract | UX Value And Benefit | Redesign Brief |
| --- | --- | --- | --- |
| Outer coaching container | `VStack` with `padding(18)` on a `GarageRaisedPanelBackground`; animated by `isShellVisible`; no direct interaction | Packages the whole coaching stack as one premium module within Garage review | Increase depth separation between shell and inner cards using a cooler cyan rim-light near active states and a warmer amber rim-light for review states |
| Container top sheen | Overlay gradient clipped to rounded rect | Adds subtle virtual light to avoid flat dark slab | Keep, but sharpen top highlight and reduce muddy midtones to improve premium contrast |
| Section card shell | `sectionCard(...)` wraps each region with stroke, optional glow, rounded radius `22`; hidden state controlled by `visibleSections` | Establishes hierarchy and staged readability | Standardize radii: outer 24, inner 20, inset 18; unify stroke opacity tokens across all Garage surfaces |
| Hero section label `Focused Analysis` | Static `Text("Focused Analysis")`; no state mutation | Immediately tells the user this is the main coaching interpretation zone | Increase letter spacing slightly less; current label is a little too washed out for the dark backdrop |
| Hero headline `Coaching unavailable` | `presentation.headline`; in live adapter this is forced when `report.cues.isEmpty` | Explicitly communicates that the app is withholding a strong interpretation | Replace with explicit unavailable mode copy driven by a typed enum, not inferred from empty cues |
| Confidence badge `REVIEW` | `GarageCoachingBadge`; tint resolved by string comparison in `badgeTint(for:)`; sourced from `GarageReliabilityStatus.review.rawValue` uppercased | Gives a quick trust-level cue without requiring the user to read the paragraph | Stop using raw strings; pass `GarageReliabilityStatus` directly and render icon plus label for faster semantic read |
| Phase badge `IMPACT` | `GarageCoachingBadge`; always tinted cyan; value from `selectedPhase.reviewTitle` | Grounds the message in a specific swing checkpoint | Differentiate phase pills from status pills more clearly; right now both read as equal-priority statuses |
| Hero body fallback copy | If no primary cue exists, body becomes `Review the motion and stability metric while coaching catches up.` | Keeps the card from collapsing into a dead empty state | Rewrite as an actionable sentence tied to exact blockers, for example keyframe trust, anchor coverage, or pose confidence |
| Supporting-line row | Hidden in this screenshot because `supportingLine == nil` when unavailable | In ready states it softens overconfidence with “cue, not final judgment” framing | Replace the optional free-text line with a reusable disclaimer chip style tied to trust state |
| Signal Mix section header | Static left label | Frames the lower cards as evidence, not the final answer | Keep |
| Signal Mix helper label `Deep-dive coaching cues` | Static right label; line-limited, scales down | Explains that tiles are secondary diagnostic evidence | Rename in review/unavailable mode to `Available evidence` because “coaching cues” implies more certainty than the state allows |
| Metric tile shell: Swing Score | `GarageCoachingMetricCard`; no tap/drag/long press; visually read-only | Gives the user one stable number even when narrative coaching is unavailable | Add subtle “read-only signal” styling so the tile stops looking like a tappable control |
| Metric tile icon: scope | `systemImage: "scope"` in fallback mode | Suggests measured evaluation | `scope` is semantically weak; use `chart.bar.xaxis`, `gauge.medium`, or a Garage-specific score glyph |
| Metric tile truncated title `Sw...` | `lineLimit(1)` with no visible tooltip | Saves horizontal space but harms scan speed | Allow two-line mini labels or shorten the canonical title to `Score`; truncation is too aggressive for a premium analytics screen |
| Metric status pill `GOOD` | `GarageCoachingMetricStatus.good`; tint cyan; derived from score thresholds | Gives quick grade context to the number | Good as a concept, but the pill should visually subordinate to the numeric value |
| Metric value `82` | Stringified score; fallback source is `scorecard?.totalScore ?? 82` in live adapter | Gives the user continuity even when coaching text is missing | Eliminate magic fallback `82`; missing score should render as `--` or a skeleton state, never a plausible fake number |
| Metric progress bar | Width = `proxy.size.width * metric.progress`, but never below `12` | Converts metric into glanceable strength | Remove hard minimum for real metrics; only keep a minimum width for loading skeletons |
| Metric tile shell: Reliability | `id == "reliability"`; treated as primary metric, value rendered in cyan if primary | Puts trust directly beside score so the user knows how much to believe the page | Use an icon-state pair, not cyan text alone; current `REVIEW` text is too visually similar to a positive neon CTA |
| Reliability icon `checkmark.shield` | Static icon regardless of status | Suggests integrity/trustworthiness | Swap icon by state: trusted `checkmark.shield`, review `exclamationmark.shield`, provisional `shield.slash` |
| Reliability status pill `WATCH` | Derived from `.review -> .watch` | Gives a nuanced signal that the metric is usable but not final | Wording collision: tile value says `REVIEW`, pill says `WATCH`; choose one trust vocabulary stack |
| Missing Session Readout section | Hidden because `presentation.snapshots.isEmpty == true` in preview; in live runtime snapshots are normally always built | Reduces clutter in fallback mock | This is a contract drift. Runtime and preview should agree. Keep the section present in review mode if score, reliability, and phase still exist |
| Next Best Action section shell | Always shown | Guarantees the screen ends with a concrete next move | Keep; it is the most behaviorally useful card on this screen |
| Next Best Action label | Cyan text | Signals this is the main take-action region | Good, but make it slightly larger or use a leading icon so it feels like the primary command surface |
| Next Best Action body | `presentation.nextBestAction`; sourced from `GarageCoachingReport.nextBestAction` | Converts analysis into behavior | Strongest value on this screen; preserve directness |
| Missing notes tray | Hidden because `presentation.notes` is empty in screenshot | Avoids redundant warnings | In review mode, prefer always surfacing at least one explicit trust blocker if one exists in reliability checks |

### Hidden And Edge States For Screenshot 1

| State | Current Behavior | Risk | Redesign Rule |
| --- | --- | --- | --- |
| `scorecard == nil` | Live adapter creates four fallback metrics: score, reliability, focus, stability | Preview drift: screenshot shows only two metrics | Make runtime and preview use one shared factory |
| `report.cues.isEmpty` | Sets headline to `Coaching unavailable` and body to generic fallback | Empty cues is not the same as system-unavailable | Introduce `GarageCoachingRenderMode` with `.ready`, `.reviewLimited`, `.unavailable`, `.provisional` |
| `stabilityScore == nil` | Fallback tile shows `--` with watch-grade default from `58` | Artificially implies known quality | Missing metrics should use explicit `missing` state, not synthetic grading |
| No notes | Action card is plain text only | Can hide the actual blocker details that caused unavailable coaching | Attach at least one blocker chip in review and unavailable modes |

## Screenshot 2: Trusted / Transition / Full Coaching State

### Screen Intent

This is the healthy coaching state. It tells the user:
- there is a primary coaching cue
- the system trusts the signal enough to say more
- the supporting score, phase, and domain metrics back up the narrative

### Component Audit

| Element | Operational Logic And Data Contract | UX Value And Benefit | Redesign Brief |
| --- | --- | --- | --- |
| Hero card glow | `sectionCard(.hero, glow: garageReviewAccent.opacity(0.35))` when not unavailable | Signals elevated confidence and importance | Good pattern; make trusted glow tighter and more localized so it feels expensive, not blurry |
| Hero label `Focused Analysis` | Static label | Anchors the top card as interpretation, not raw data | Keep |
| Hero headline `Transition appears faster than this swing's baseline` | `GarageCoachingPresentation.make(...)` remaps raw cue title `Transition Looks Rushed` to friendlier copy | Converts a technical caution into plain-language coaching | Good intent, but the adapter should not hardcode title rewrites inline; move copy mapping into a dedicated formatter |
| Status badge `TRUSTED` | Derived from `GarageReliabilityStatus.trusted` | Reassures the user that the coaching cue is usable | Add a check icon and stronger fill-stroke separation so trusted feels distinct from general cyan |
| Phase badge `TRANSITION` | `selectedPhase.reviewTitle.uppercased()` | Tells the user where to look in the motion | Good, but phase should not visually compete with trust status; use slimmer secondary pill style |
| Hero body narrative | `primaryCue.message` from `GarageCoachingCue` | Explains the observation in human language instead of just surfacing raw metrics | Strongest narrative value on the page |
| Hero disclaimer row with cyan dot | `supportingLine` currently fixed to `Use this as a cue, not a final judgment` for non-unavailable states | Prevents AI-like overclaiming | Keep the disclaimer, but reword per trust level: trusted should still be humble, review should be more cautionary |
| Session Readout section label | Static `Text("Session Readout")` | Frames the snapshot strip as summary instrumentation | Good |
| Horizontal scroller | `ScrollView(.horizontal, showsIndicators: false)`; no snapping, no interaction on cards | Lets the screen support 2-4 summary cards without vertical bloat | Since the current card count is tiny and known, a fixed row may be cleaner than a scroll view |
| Snapshot card icon halo | Circle with accent background plus SF Symbol | Creates a premium dashboard-card feel | Good foundation; icon halos need stronger tint differentiation by card type |
| Snapshot card `Session Analysis / 87 / swing score` | Built from `scorecard.totalScore` or fallback | Gives a global quality read before domain details | Keep |
| Snapshot card `Reliability / TRUSTED / signal confidence` | Built from `GarageReliabilityStatus` | Makes trust explicit without opening another details screen | Keep, but align terminology with the hero badge so the user is not parsing two different trust labels |
| Snapshot card `Focus Phase / Transition / stability 82` | Built from `selectedPhase.reviewTitle` plus `stabilityScore` caption | Shows what phase is being emphasized and the supporting stability context | Mixed semantics: title is phase, caption is stability. Split these into separate ideas or rename card to `Focus And Stability` |
| Signal Mix section left label | Static | Introduces domain metrics | Keep |
| Signal Mix helper label | Static right-side helper | Provides context | In trusted mode the wording works; in review mode it should soften |
| Metric tile `Tempo` | Comes from `GarageSwingDomain.tempo` and `GarageSwingDomainScore.displayValue` | Surfaces timing rhythm as a domain cue | Strong |
| Tempo icon `metronome` | Semantic SF Symbol | Immediately readable | Strong |
| Tempo status `GREAT` | `GarageMetricGrade.excellent -> GarageCoachingMetricStatus.great` | Reassures user that rhythm is not the main issue | Strong |
| Tempo value `3.0:1` | `displayValue` from scorecard | Gives a concrete measurement | Strong, but use a thin-space or consistent formatting token across all ratios |
| Metric tile `Spine` | From domain scorecard | Summarizes posture change | Strong |
| Spine icon `angle` | Semantic but abstract | Hints at angular delta | Replace with a more body-relevant symbol if possible; `angle` feels generic |
| Spine value `6.8°` | String display value | Gives a compact biomechanics cue | Good |
| Metric tile `Pelvis` | From domain scorecard | Shows depth/space preservation | High coaching relevance | Rename to `Pelvic Depth` or `Depth` to match the actual metric contract and reduce ambiguity |
| Pelvis icon `arrow.left.and.right` | Generic horizontal movement icon | Suggests lateral movement | Replace with a body-center depth icon or custom glyph; current icon is too generic |
| Pelvis status `WATCH` | Derived from fair grade | Flags a likely contributing issue | Strong concept, but color and pill feel too similar to trusted/review badges elsewhere |
| Pelvis value `1.9 in` | Domain display value | Makes the caution more concrete | Good |
| Reliability metric tile | Appended after domain tiles in `metricTiles(...)` | Brings trust back into the evidence grid | Useful, but slightly redundant with hero badge and session readout |
| Reliability value `TRUSTED` in cyan | Since `id == "reliability"`, value gets primary styling | Reinforces trust in the evidence set | Consider moving reliability out of the metric grid and into a dedicated trust rail to avoid over-repetition |
| Metric progress bars | Domain score normalized from `0...100`; reliability normalized from enum constants `0.92/0.68/0.34` | Lets the user compare relative strength across cues quickly | Good concept, but enum-based normalized values are magic numbers; move them into a shared trust visual scale token |
| Missing notes tray in trusted screenshot | `presentation.notes` empty because trusted state usually has no blockers | Keeps the flow clean | Good |

### Hidden And Edge States For Screenshot 2

| State | Current Behavior | Risk | Redesign Rule |
| --- | --- | --- | --- |
| `syncFlow.primaryIssue` present | Inserted at index `0` as top cue when `syncFlow.status == .ready` | Great signal, but can overshadow scorecard cues too aggressively | Add cue provenance so the hero can show whether it came from SyncFlow or scorecard logic |
| No caution cues in trusted mode | `nextBestAction` becomes a generic “keep building comparable swings” sentence | Can feel vague after a strong-looking report | Prefer a concrete reinforcement action even in positive states |
| Odd metric count | Last tile becomes full-width capstone | Good visual cleanup | Preserve |
| Long metric values | `lineLimit(2)` with `minimumScaleFactor` | Can still compress too hard on small phones | Introduce value typography tiers by metric type |

## Interaction Audit

### What Actually Interacts Today

| Element | Current Interaction | State Mutation |
| --- | --- | --- |
| Whole coaching screen | Entrance `.task(id:)` animation only | Mutates `isShellVisible`, `visibleSections`, `lastAnimatedEntranceKey` |
| Hero badges | None | None |
| Snapshot cards | None | None |
| Metric tiles | None | None |
| Progress bars | None | None |
| Next Best Action card | None | None |

### Why This Matters

- The visual language suggests interactivity, especially on tiles and pills.
- Because nothing is tappable, the screen is currently an information panel, not a tool surface.
- That is acceptable if the styling communicates “instrument cluster.”
- It is not acceptable if pills keep looking like buttons.

### Redesign Interaction Rule

Choose one of these and stay consistent:
- Make tiles explicitly read-only with lower relief and calmer borders.
- Or make selected surfaces tappable and route into evidence detail, reliability checks, or phase review.

Do not leave them visually ambiguous.

## Data Contract Audit

### Primary Domain Inputs

| UI Field | Current Source | Notes |
| --- | --- | --- |
| `headline` | `GarageCoachingReport.headline`, sometimes remapped in presentation | Good source, weak formatting seam |
| `body` | `GarageCoachingCue.message` or generic fallback copy | Good source |
| `confidenceLabel` | `GarageReliabilityStatus.rawValue` stored as `String` | Should stay typed as enum |
| `phaseLabel` | `SwingPhase.reviewTitle` stored as `String` | Should stay typed as phase |
| `nextBestAction` | `GarageCoachingReport.nextBestAction` | Strong |
| `notes` | `GarageCoachingReport.blockers.prefix(2)` | Good, but naming should communicate trust blockers |
| Session score | `GarageSwingScorecard.totalScore` or fallback `82` | Fallback is not acceptable |
| Session reliability | `GarageReliabilityStatus` | Good |
| Focus phase | `selectedPhase.reviewTitle` | Good |
| Stability caption | `stabilityScore` or `stability pending` | Mixed with phase snapshot in a slightly muddy way |
| Metric tiles | `GarageSwingScorecard.domainScores` plus appended reliability tile | Good structure |

### Data Accuracy Risks

- Stringly typed trust and phase values make it easy for preview, formatting, tinting, and accessibility to drift.
- Score fallback `82` can misrepresent missing data as real data.
- Stability tile fallback grades `58` when missing, which invents confidence.
- Preview fixtures are not enforcing the same rules as the live adapter.
- The same reliability concept is rendered three times with slightly different wording and visual weight.

## Architecture Refactor Plan

### 1. Replace Stringly Presentation With Typed View State

Create a typed render model:

| New Type | Responsibility |
| --- | --- |
| `GarageCoachingRenderMode` | `.ready`, `.review`, `.unavailable`, `.provisional` |
| `GarageCoachingHeroModel` | Headline, body, trust state, phase, disclaimer, cue provenance |
| `GarageCoachingSnapshotModel` | Snapshot cards only |
| `GarageCoachingMetricModel` | Metric title, semantic kind, display value, status, progress |
| `GarageCoachingActionModel` | Primary action plus optional blockers |

This keeps product logic out of the raw SwiftUI view tree.

### 2. Normalize Trust Vocabulary

Current trust words:
- hero badge: `TRUSTED` or `REVIEW`
- reliability tile value: `TRUSTED` or `REVIEW`
- metric pill: `GREAT`, `WATCH`

Redesign to one vocabulary stack:
- Trust state: `Trusted`, `Review`, `Provisional`
- Performance grade: `Great`, `Good`, `Watch`, `Needs Work`

Never mix trust state and performance grade on the same visual line without separation.

### 3. Separate Missing Data From Weak Data

Current behavior blurs:
- unavailable
- incomplete
- review
- synthetic fallback values

Redesign rule:
- Missing data renders as missing.
- Review data renders as review.
- Unavailable coaching renders as unavailable.
- No synthetic metric numbers.

### 4. Remove Preview Drift

Build all previews from the same production adapter path.

Required rule:
- preview fixtures can seed inputs
- preview fixtures cannot hand-author impossible output states that runtime cannot produce

### 5. Simplify View Responsibilities

`GarageCoachingReportView` should only:
- render
- animate section entrance
- route taps if the redesign adds drill-downs

It should not:
- infer status from strings
- rewrite copy
- decide missing-data semantics

### 6. Improve Accessibility And Readability

- Give trust badges explicit accessibility labels using enum-driven language.
- Stop truncating important titles to unreadable fragments.
- Promote the primary action and demote redundant helper copy.
- Ensure all contrast levels survive low-brightness dark mode.

## Visual Redesign Directives

### Surface System

- Outer shell: deeper charcoal base with tighter ambient shadow.
- Inner cards: slightly warmer raised plane for separation.
- Inset cards: lower-luminance, flatter interior to frame data.
- Trusted state: concentrated cyan glow, not a broad haze.
- Review state: amber edge-light, not just orange text.
- Provisional state: muted red with lower saturation to avoid alarm fatigue.

### Typography

- Hero headline gets one clear tier above everything else.
- Status and phase pills get differentiated weight and opacity.
- Section headers should be quieter than values but crisper than current washed labels.
- Numeric values need a consistent mono-ish or rounded numeric system for precision feel.

### Iconography

- Use trust-specific shield variants.
- Replace generic movement icons where the metric contract is more specific than the symbol.
- Keep icon count low; every icon should earn its place semantically.

### Motion

- Preserve staggered reveal.
- Add subtle card shimmer only for loading skeletons, never for completed data.
- If drill-down taps are added, use a calm press-down inset reaction with light haptic feedback.

## Implementation Boundaries

Stay inside Garage.

Touch points should remain limited to:
- `GarageCoachingReportView.swift`
- `GarageView.swift`
- `GarageAnalysis.swift`
- targeted Garage tests

Do not push coaching-specific state into the shared shell.

## Test Plan For The Refactor

### Unit Tests

- presentation mode for `ready`
- presentation mode for `review`
- presentation mode for `unavailable`
- presentation mode for `provisional`
- no synthetic score when scorecard is missing
- no synthetic stability grade when stability is missing
- reliability vocabulary remains distinct from performance grade vocabulary
- preview builders use production adapter path

### UI Or Snapshot Checks

- trusted hero with three snapshots and six metrics
- review hero with blockers tray
- unavailable hero with explicit missing-data styling
- odd metric count capstone layout
- long metric title and long value on small phone width

## Final Redesign Decisions

### Keep

- stacked card architecture
- staggered entrance animation
- session summary + metric evidence + action sequence
- odd-count capstone metric handling

### Change

- replace string-driven trust and phase rendering with typed models
- remove fake fallback numbers
- distinguish trust state from performance grade visually and semantically
- unify preview/runtime contracts
- make review and unavailable states explicit, not inferred
- either commit to read-only instrumentation styling or add real drill-down interactions

### Remove

- unused `presentation.title`
- inline headline rewrite special-casing in the presentation adapter
- ambiguous icon choices that do not match the underlying metric contract

## Recommended Phase 5 Refactor Slice

1. Build typed coaching render models and explicit render modes.
2. Refactor the presentation adapter to produce only truthful, non-synthetic states.
3. Update the report view to render trusted, review, unavailable, and provisional modes distinctly.
4. Tighten typography, icon semantics, and neumorphic depth.
5. Add targeted tests for state truth and preview/runtime parity.
