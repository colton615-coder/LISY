# Garage Evidence Navigation Design

- Status: proposed
- Scope: Garage analyzer evidence navigation only
- Authoritative for: `GarageCoachingPresentation.swift`, `GarageCoachingReportView.swift`, `GarageReviewWorkspace.swift`, and targeted Garage analyzer tests
- Does not change: shared shell routing, module ownership, analyzer measurement boundaries, or unsupported 3D claims
- Date: 2026-04-22

## Goal

Turn the Garage coaching report from a static explanation surface into a trust-building evidence launcher.

The key user outcome is:
- the user taps a cue such as `Hip Stall` or `Early Hands`
- Garage physically routes playback and the review workspace to the exact supporting evidence
- trust increases because the app shows the moment instead of only describing it

This is an analysis-trust feature delivered through a visible premium interaction.

## Current Problem

The current Garage analyzer report is visually premium and already has typed presentation models, but the trust loop still stops too early.

Today:
- `GarageCoachingPresentation.swift` carries typed report models and detail targets
- `GarageCoachingReportView.swift` supports tap-driven drill-downs
- the current drill-down destination is still a modal detail surface, not the live evidence moment inside review

This creates a gap:
- the analyzer can state a coaching cue
- the report can explain a cue
- but the user still has to trust that the cue maps to something real in the motion

For a swing analyzer, that gap is expensive. Static copy is easier to doubt than a physical jump to the exact frame or evidence window.

## Approved Direction

Use inline cue-to-playback evidence navigation inside Garage.

Why:
- it directly converts a claim into a visible proof action
- it fits the analyzer checkpoint already called out in the current docs
- it preserves Garage-local ownership by keeping the jump inside the review workspace
- it produces immediate user-visible payoff without requiring a full analyzer-mode rebuild

This is the recommended `Option B` implementation path.

## Core Product Rule

The report explains.
The jump proves.
The workspace confirms.

That division should remain strict.

`GarageCoachingReportView` must not become a second review canvas.
`GarageReviewWorkspace` must remain the only place that owns playback, frame selection, and visual evidence emphasis.

## Interaction Model

### High-Level Behavior

Every trust-critical interactive report item should launch a real evidence jump when Garage can defend that jump honestly.

The first-release surface area should stay intentionally small:
- primary coaching cues such as `Hip Stall` and `Early Hands`
- reliability blockers such as low pose confidence or untrusted review state
- a limited set of high-value metrics only when they map cleanly to real evidence

Tap behavior:
1. user taps an evidence-enabled item in the coaching report
2. Garage performs a light haptic and a restrained pressed-state response
3. Garage routes the review workspace to the mapped evidence target
4. playback lands on the exact frame or selected evidence window
5. the relevant phase, checkpoint, or blocker context becomes active
6. Garage shows a brief arrival emphasis so the user feels guided to proof

There should be no confirmation sheet on the happy path.

### Honest Evidence Rule

Garage must not fake precision.

If a cue does not have defensible exact evidence:
- do not route to an invented frame
- route to a directional phase window if that is honest
- or route to a review blocker / trust explanation state
- or remove the affordance entirely

The trust win comes from honesty plus physicality, not from theatrical behavior detached from real data.

## Routing Contract

### Ownership

Evidence navigation is a Garage-local routing seam.

Responsibilities:
- `GarageCoachingReportView` emits a typed evidence intent
- `GarageReviewWorkspace` resolves that intent into playback, selected frame, selected phase, and temporary arrival emphasis
- no shell-level route changes
- no cross-module handoff

### New Typed Target

Introduce a Garage-local model:

```swift
enum GarageEvidenceTarget: Equatable {
    case checkpoint(
        frameIndex: Int,
        phase: SwingPhase,
        emphasis: GarageEvidenceEmphasis
    )
    case phaseWindow(
        startFrameIndex: Int,
        endFrameIndex: Int,
        selectedFrameIndex: Int,
        phase: SwingPhase,
        emphasis: GarageEvidenceEmphasis
    )
    case reliabilityIssue(
        kind: GarageEvidenceReliabilityKind,
        relatedFrameIndex: Int?,
        phase: SwingPhase?
    )
    case reviewNote(
        noteID: String,
        relatedFrameIndex: Int?,
        phase: SwingPhase?
    )
}
```

Support types should remain narrow and Garage-local:

```swift
enum GarageEvidenceEmphasis: Equatable {
    case coachingCue(String)
    case metric(String)
    case blocker(String)
}

enum GarageEvidenceReliabilityKind: Equatable {
    case lowPoseConfidence
    case missingKeyframeCoverage
    case reviewNotApproved
    case incompleteAnchorCoverage
    case unavailableReviewSource
}
```

The names can change during implementation, but the contract shape should not:
- one typed target per interactive report item
- exact evidence and directional evidence represented differently
- trust/blocker routing represented separately from biomechanical cue routing

### Presentation Contract

`GarageCoachingPresentation` should carry optional evidence targets on the interactive report items.

Recommended shape:
- cues, snapshots, and selected metrics may include `evidenceTarget: GarageEvidenceTarget?`
- items without defensible evidence stay visually passive
- evidence-capable items get explicit affordance styling

V1 scope guard:
- do not require a brand-new top-level cue model if the current presentation can attach evidence to existing hero, snapshot, metric, or action-level items cleanly
- only introduce a dedicated cue model if the current typed presentation cannot represent evidence-enabled coaching cues without distortion

`GarageCoachingReportView` must not infer evidence routing from strings like `Hip Stall` or `Early Hands`.
All evidence targets should arrive already typed from the analyzer/presentation seam.

### Workspace Contract

Add one Garage-local entry point in the review workspace:

```swift
func navigateToEvidence(target: GarageEvidenceTarget)
```

This function should be the only place that:
- resolves the target
- updates `currentFrameIndex`
- updates `currentTime`
- selects the active checkpoint or phase context
- triggers temporary arrival emphasis
- falls back honestly if full resolution is not possible

## UI Behavior

### Coaching Report

Interactive evidence items must look different from passive informational items.

Recommended rules:
- use one consistent evidence affordance, not mixed patterns
- prefer a full-row press response or a compact `View Evidence` treatment
- do not rely on a generic chevron alone
- the user should understand that the action launches proof, not just details

Press behavior:
- light haptic
- short tactile inset state
- immediate handoff into the review workspace

### Review Workspace Arrival

The arrival moment is the trust-maker.

After a successful evidence navigation event, the review workspace should coordinate:
- playback scrub to the mapped frame or evidence window
- phase or checkpoint activation
- localized skeleton / overlay emphasis
- brief evidence label such as `Evidence: Early Hands`

Recommended visual treatment:
- concentrated cyan emphasis for evidence-backed coaching cues
- review-limited or blocker states use softer caution styling, not the same confident accent
- a brief focus pulse and timeline emphasis that fades after roughly 1 second

The user should be left in full manual control after the arrival emphasis completes.

### Directional vs Exact Evidence

Exact evidence:
- lands on one defensible frame or checkpoint
- uses direct evidence labeling

Directional evidence:
- lands inside a phase window
- labels the state as directional evidence
- avoids any copy that implies exact break detection

Trust / blocker evidence:
- routes to the closest useful context with an honest blocker label
- can use a related frame when available
- must not present itself as proof of a swing fault

## Data Derivation Contract

### Derivation Location

Evidence targets should be produced near the Garage analysis / presentation seam, not in the raw SwiftUI layer.

Best fit:
- analysis domain computes or exposes real frame indices or phase windows
- `GarageCoachingPresentation` adapts that domain output into interactive report items
- `GarageCoachingReportView` renders the result without reinterpretation

### Supported Evidence Levels

#### Exact checkpoint evidence

Use when:
- the cue maps cleanly to one frame or one checkpoint

Examples:
- a cue tied to a known phase break
- a cue tied to a stable checkpoint comparison

#### Phase-window evidence

Use when:
- the evidence is more honest as a short motion sequence

Examples:
- sequence timing issues
- transition-shape problems better understood across several adjacent frames

#### Trust / blocker evidence

Use when:
- the user needs to understand why Garage is limiting confidence
- the issue is missing coverage, low pose confidence, or incomplete review trust

This keeps biomechanics evidence distinct from measurement trust evidence.

### First-Release Scope Guard

Only cues with defensible mappings should ship with evidence jumps.

Do not attempt a universal mapping layer in v1 of this feature.

The initial implementation should deliberately exclude:
- cues that only have narrative wording with no frame-backed derivation
- metrics that collapse too much information to one dishonest jump target
- any interaction that depends on unsupported 3D certainty

## Failure Handling

### Missing Or Stale Derived Data

If the derived payload is stale or incomplete:
- do not expose exact evidence navigation
- downgrade the item to passive or blocker-routing behavior
- surface reanalysis or review-needed framing when required

### Out-Of-Range Targets

If a target frame falls outside the available frame range:
- clamp to the nearest valid frame
- mark the arrival as directional if precision has been reduced

### Video Missing But Pose Review Available

If video is unavailable but fallback pose review exists:
- allow evidence routing into pose-backed review context
- do not imply full-fidelity video proof

### Provisional Trust State

If the swing is provisional:
- evidence jumps may still exist where honest
- arrival styling and copy must reflect reduced trust
- provisional states should never look identical to trusted cue proof states

### Unsupported Evidence

If a cue cannot be defended:
- remove the evidence affordance entirely
- do not ship “smart-feeling” but unverifiable jumps

## Testing Contract

This feature needs targeted truth tests, not broad unrelated verification.

### Unit Tests

Add focused tests for:
- exact cue maps to the intended checkpoint / frame
- phase-window cue maps to the intended frame range and selected arrival frame
- reliability blocker maps to blocker evidence without fake precision
- provisional states downgrade evidence affordance honestly
- stale or missing derived payload disables or degrades navigation correctly
- out-of-range targets clamp safely

### Integration Checks

Add targeted Garage checks that confirm:
- tapping a report evidence item updates `currentFrameIndex`
- `currentTime` and frame selection stay in sync
- selected phase / checkpoint updates with the evidence jump
- temporary arrival emphasis clears after its display window
- routing remains fully inside Garage

### Final UI Evidence Pass

Do one end-of-slice visual validation for:
- one trusted exact evidence jump
- one review-limited directional evidence jump
- one reliability blocker jump
- one passive item with no evidence affordance

## Implementation Boundaries

Keep the first slice limited to:
- `GarageCoachingPresentation.swift`
- `GarageCoachingReportView.swift`
- `GarageReviewWorkspace.swift`
- only the minimum Garage analysis derivation changes needed to expose honest evidence targets
- targeted Garage tests

Do not:
- move playback control into the report
- add shell routing
- broaden this into a complete analyzer-mode rewrite
- imply unsupported 3D or segment-level certainty

## Risks And Guards

### Risk: The feature becomes a flashy shortcut instead of proof

Guard:
- require typed evidence targets from real analyzer output
- disable unsupported routes instead of guessing

### Risk: Report UI becomes overloaded

Guard:
- keep only trust-critical items interactive in the first slice
- use one evidence affordance pattern consistently

### Risk: Review workspace gains brittle ad hoc navigation code

Guard:
- centralize behavior under one `navigateToEvidence(target:)` seam
- keep arrival emphasis temporary and self-contained

### Risk: Exactness is overstated

Guard:
- separate exact, directional, and blocker evidence into different target types
- label them differently in the UI

### Risk: Scope expands into a full analyzer redesign

Guard:
- keep this slice focused on evidence routing only
- defer full evidence-first analyzer mode to a future project

## Acceptance Check

This design is successful when:
- at least one primary coaching cue can jump from the report into real playback evidence
- the jump lands on a defensible frame or phase window
- the workspace visibly confirms the evidence moment with brief restrained emphasis
- trust-related blockers route honestly without fake biomechanical precision
- unsupported cues remain passive
- all routing stays inside Garage and respects current analyzer architecture

## Implementation Slice

This is one bounded Garage analyzer feature slice:
- add typed evidence targets to the coaching presentation seam
- convert selected report items into evidence launchers
- add Garage-local workspace evidence navigation and arrival emphasis
- verify truth behavior with targeted Garage tests

The purpose is not to make the report larger.
The purpose is to make the analyzer more believable by letting the user touch the claim and see the proof.
