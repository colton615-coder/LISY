# Garage Module UX/UI Audit — Spec + Implementation Plan

> [!WARNING]
> Historical document. Non-authoritative. Do not use for implementation.

## Status: archived historical module implementation plan.


## Context
This plan converts the Garage UX/UI audit into an implementable engineering spec for the existing SwiftUI architecture. It is based on current code behavior in `GarageView`, shared module scaffolding in `SharedModuleUI`, and keyframe detection logic in `GarageAnalysis`.

## Current-State Findings (Code-Verified)

### 1) Entry/import flow has extra steps and a confirmation gate
- `GarageView` presents `AddSwingRecordSheet` before importing media, which creates an intermediate "New Swing Record" screen.  
- The sheet requires explicit Save after picking a video (`Save` toolbar button), rather than auto-import.  
- Picker is already filtered to `.videos`, which aligns with the audit requirement.

### 2) Garage screen inherits command-center cards and non-essential review chrome
- `GarageView` is hosted in `ModuleHubScaffold`, which always renders:
  - Command Center hero
  - Current State card
  - Next Attention card
- `GarageReviewTab` includes a `Details` sheet and supporting “Swing Details” UI that adds non-analysis chrome.

### 3) Review surface is split video + controls; not immersive-first
- `GarageFocusedReviewWorkspace` uses a side-by-side composition with frame surface and extensive right-pane UI.
- Visual overlays always draw sampled skeleton/wrist lines for current frame when frame data exists.
- Pose fallback mode intentionally draws reconstruction UI and explanatory labels.

### 4) Checkpoint timing and tracking concerns map to deterministic pipeline heuristics
- Early Downswing is derived by distance interpolation from transition→impact; this can drift later than expected in some swings.
- Manual correction exists today (adjust phase frame + hand anchor), but UX discoverability and per-point override coverage can be improved.

### 5) Status pills can truncate under tight width
- Multiple status chips use capsule text without explicit minimum scale factor or overflow handling.

---

## Product Spec (Target Behavior)

## A. Entry & Import Logic
### A1. Direct media-first flow (no intermediate form before import)
**Requirement**
- Tapping “Add Swing Record” should immediately open the iOS media picker.
- Picker only allows videos.
- On selection, import + analysis begins automatically.
- No final confirmation step for import.

**Implementation shape (low-blast-radius)**
1. Replace `AddSwingRecordSheet` as the primary entry flow with an inline importer controller/state in `GarageView` (or a dedicated lightweight import sheet that auto-runs import on selection and dismisses itself).
2. Preserve optional metadata editing as post-import action (e.g., rename/notes from review context), not pre-import blocker.
3. Keep `.photosPicker(... matching: .videos ...)` as-is for media filtering.

**Acceptance criteria**
- Add button → picker opens in one interaction.
- Selecting a video starts progress immediately.
- Record appears and review tab auto-selects after analysis completes.
- No explicit Save tap required to create record.

## B. Dashboard & Interface Cleanup
### B1. Garage-specific scaffold mode: minimal review shell
**Requirement**
- Remove Garage command-center aesthetic clutter:
  - Command Center hero
  - Current State / Next Attention cards
  - related card actions
- De-emphasize card-based “My Swing in Two” style layouts.
- Prioritize full-screen analysis video.

**Implementation shape**
1. Extend `ModuleHubScaffold` with configuration flags (or a display mode enum) so Garage can disable hero/status blocks while preserving tab infrastructure for other modules.
2. In Garage review tab, remove `Details` button/sheet from primary review UI.
3. Collapse overview-style cards for Garage into compact actions or route users directly to Records/Review.

**Acceptance criteria**
- Garage screen renders without hero/current/next cards.
- Review experience launches directly into analysis surface, not card stack.
- No visible “Details” tab/button in primary review workflow.

## C. Analysis & Scrubbing Precision
### C1. Raw-frame-first scrubbing
**Requirement**
- During scrubbing, raw video frames must be visible without sampled pose skeleton overlays.

**Implementation shape**
1. Add overlay mode state in `GarageFocusedReviewWorkspace`:
   - `.none` (default for scrubbing)
   - `.anchorOnly`
   - `.diagnosticPose` (optional/debug)
2. In `GarageReviewFrameOverlayCanvas`, gate skeleton/wrist rendering behind mode; keep anchor marker available.
3. In pose-fallback mode (no video available), keep fallback rendering but explicitly indicate reduced precision.

**Acceptance criteria**
- When video frame exists, skeleton lines/pose dots are not shown by default while scrubbing.
- Anchor marker remains visible/editable.

### C2. Tracking pinpoint and manual override completeness
**Requirement**
- Improve hand/grip auto-point reliability and guarantee user override for all automated points.

**Implementation shape**
1. Expand manual override model from selected phase only to any phase via checkpoint strip selection + adjust action (mostly already present; tighten UX and persistence guarantees).
2. Ensure manual anchor source is preserved through recomputation/merging.
3. Add confidence-aware visual hinting (low-confidence auto points subtly marked, never blocking manual edit).

**Acceptance criteria**
- Every checkpoint can be manually re-framed and re-anchored.
- Saved manual points remain stable after reload and subsequent status changes.

### C3. Checkpoint alignment correction (Early Downswing drift)
**Requirement**
- Correct phase synchronization so “Early Downswing” does not appear post-impact.

**Implementation shape**
1. Tighten temporal constraints in `GarageAnalysisPipeline`:
   - Enforce strict ordering: `transition < earlyDownswing < impact`.
   - Add max-distance-to-impact and pre-impact velocity sign checks.
2. Add deterministic fallback when heuristics conflict:
   - choose earliest candidate satisfying both ordering and downswing directionality.
3. Add regression tests with representative frame fixtures for late-trigger scenarios.

**Acceptance criteria**
- Early Downswing index always `< impactIndex`.
- Regression fixtures pass and no phase order inversions occur.

## D. Visual Polish
### D1. Status pill truncation hardening
**Requirement**
- Approved/Flagged/Pending pills should never clip/truncate awkwardly.

**Implementation shape**
1. Update pill views (`GarageCheckpointStatusBadge`, `GarageReviewStatusPill`, summary pills) with:
   - `.lineLimit(1)`
   - `.minimumScaleFactor(0.85)` where needed
   - adaptive horizontal padding and optional icon-first compact mode
2. In tight horizontal layouts, allow wrap to second row or switch to icon-only summary with accessibility label.

**Acceptance criteria**
- No truncation on iPhone SE width class and split view compact widths.

---

## Technical Plan by Milestone

## Milestone 1 — Import Workflow Refactor (highest impact)
- Remove Save-gated pre-import flow.
- Trigger picker directly from Add Swing Record.
- Auto-import immediately after video pick.
- Preserve robust progress/error overlays.

**Files likely touched**
- `LIFE-IN-SYNC/GarageView.swift`

## Milestone 2 — Garage Minimal Shell
- Add Garage-specific scaffold configuration (hide hero/current/next).
- Remove review details sheet from primary path.
- Keep tabs only if they remain useful; otherwise bias to Records + Review.

**Files likely touched**
- `LIFE-IN-SYNC/SharedModuleUI.swift`
- `LIFE-IN-SYNC/GarageView.swift`

## Milestone 3 — Precision Review Surface
- Introduce overlay mode + raw-frame default.
- Ensure anchor-only editing remains first-class.
- Keep fallback visuals only when no video frame exists.

**Files likely touched**
- `LIFE-IN-SYNC/GarageView.swift`

## Milestone 4 — Keyframe Alignment Fix + Tests
- Refine early-downswing heuristic.
- Add deterministic regression tests for phase ordering and known drift cases.

**Files likely touched**
- `LIFE-IN-SYNC/GarageAnalysis.swift`
- `LIFE-IN-SYNCTests/GarageDerivedReportsXCTests.swift` (or new targeted Garage keyframe tests)

## Milestone 5 — Visual Polish Pass
- Harden all Garage pills/chips against clipping.
- Validate compact width behavior.

**Files likely touched**
- `LIFE-IN-SYNC/GarageView.swift`

---

## Test and Validation Strategy

## Automated
1. **Pipeline unit tests**
   - Early Downswing before Impact invariant.
   - Ordered keyframe monotonicity across all phases.
2. **UI state tests (where available)**
   - Add Swing Record opens picker immediately.
   - Auto-import creates record without Save interaction.
3. **Snapshot/visual checks (if present)**
   - Compact width status pills are readable/no truncation.

## Manual QA checklist
- Import path from Add button is one-step into picker.
- Selecting a video immediately starts import.
- Review opens with raw frame visible while scrubbing.
- Manual checkpoint frame + hand-anchor override works for every phase.
- Early Downswing appears pre-impact on challenging clips.
- No command-center hero/current/next cards in Garage.

---

## Risks and Mitigations
- **Risk:** Removing pre-import form may reduce metadata capture.
  - **Mitigation:** Provide post-import rename/notes edit affordance.
- **Risk:** Shared scaffold changes could affect other modules.
  - **Mitigation:** Add opt-in Garage-only display mode; default behavior unchanged.
- **Risk:** Heuristic changes could regress other swing types.
  - **Mitigation:** Add fixture-based regression suite before/after heuristic adjustment.

---

## Definition of Done
- Garage import flow is direct, video-only, and auto-importing.
- Garage UI is minimal and analysis-first with immersive video priority.
- Scrubbing defaults to raw frames (no sampled pose overlay noise).
- Manual overrides are complete and durable.
- Early Downswing synchronization issue is corrected and test-covered.
- Status pills render cleanly at compact widths.
