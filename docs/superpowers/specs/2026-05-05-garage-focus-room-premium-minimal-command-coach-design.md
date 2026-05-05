# Garage Focus Room Premium-Minimal Command Coach Design

- Status: approved
- Scope: Garage Focus Room refactor only
- Authoritative for: Focus Room structure extraction, friction reduction behavior, and Command Coach copy contract
- Does not change: SwiftData models, persistence contracts, global state architecture, or module boundaries
- Date: 2026-05-05

## Goal

Refactor Garage Focus Room into a premium-minimal execution surface that reduces in-session friction while preserving measured-analysis discipline.

The user outcome is:
- the user opens Focus Room and knows the next action immediately
- drill progression requires fewer decisions and fewer taps
- rep validation is handled in Review, not during active execution
- copy is command-driven and observable, never hype-driven

## Locked Constraints

- `GarageActiveSessionView.swift` remains orchestration and source of truth.
- Extracted Focus Room views remain stateless and presentation-first.
- `GarageFocusRoomCopy.swift` contains copy tokens/constants only.
- `GarageFocusRoomCopy.swift` contains no behavior logic, no state decisions, no computed routing, and no persistence decisions.
- No SwiftData model changes.
- No persistence contract changes.
- No global state additions.
- No module boundary changes.
- No unrelated Garage modules/screens touched.
- Build-only verification is sufficient unless implementation uncovers a high-risk layout issue.
- No simulator run or screenshot verification required by default.

## 1) Architecture + File Boundaries

### Ownership Model

Keep the current ownership model intact:
- `GarageActiveSessionView` owns phase state, route transitions, save invocation, and error handling.
- Extracted Focus Room components render UI from explicit inputs and bindings.
- Save/session persistence remains on the current end-of-session path.

### File Plan

Modify:
- `LIFE-IN-SYNC/Garage/GarageActiveSessionView.swift`

Create:
- `LIFE-IN-SYNC/Garage/GarageFocusRoomView.swift`
- `LIFE-IN-SYNC/Garage/GarageFocusRoomHeader.swift`
- `LIFE-IN-SYNC/Garage/GarageFocusDrillPrimaryCard.swift`
- `LIFE-IN-SYNC/Garage/GarageFocusDrillActionDock.swift`
- `LIFE-IN-SYNC/Garage/GarageFocusDrillStackRail.swift`
- `LIFE-IN-SYNC/Garage/GarageFocusRoomCopy.swift`

### Fragmentation Guardrail

Do not over-fragment one-off UI into tiny files. Extract only components that are structurally meaningful and improve readability/iteration speed.

## 2) Behavior Flow + Focus Room Friction Reductions

### Phase Flow

Phase model remains:
- Lobby
- Focus Room
- Review

### Focus Room Entry Behavior

- Focus Room opens on the first unresolved drill.
- If all drills are already resolved when Focus Room opens, route directly to Review.

### Active Drill Progression

- Primary CTA is `Mark Drill Complete` while unresolved drills remain.
- Marking a drill complete auto-advances to the next unresolved drill.
- Completing the last unresolved drill routes directly to Review.

### Rep Review Flow

- Rep validation belongs in Review, not Focus Room.
- Rep values must remain explicit and editable.
- Rep values must never be silently inferred.
- Review remains the only place where rep values are finalized.

### Drill Detail Density

Default active card sections:
- `Objective`
- `Execution Command`
- `Pass Check`

Deeper details behind one expandable region:
- `Drill Detail`
- `Setup`
- `Common Miss`
- `Reset Cue`
- `Equipment`
- `Rep Target`

### Primary Action Clarity

- Bottom dock exposes one dominant CTA at a time:
  - `Mark Drill Complete` while unresolved drills remain
  - `Enter Review` when all drills are resolved
- Secondary controls stay minimal:
  - `Back`
  - `Add Note` / `Edit Note` only if sheet flow is stable
  - Optional drill list jump only if lightweight

### Upcoming/Completed Awareness

Compact drill rail is approved for:
- current position
- upcoming drills
- completed markers
- completed drills tappable for quick revisit/edit

Do not let the compact rail become a full secondary navigation system.

### Note + Dock Safety

- Note editing uses a sheet-only flow.
- No inline keyboard in Focus Room body.
- Avoid keyboard/dock overlap and dock-jump instability.

### Bottom Dock/Inset Safety

- Fixed bottom dock must not obscure content, drill text, review rows, or CTA areas.
- Content inset and safe-area handling must explicitly clear dock height.

## 3) Command Coach Copy System

### Tone Rules

- Imperative coaching language.
- Short, observable, action-first copy.
- Neutral confidence only.
- No hype language.
- No motivational fluff.
- No slang.
- No exclamation marks.
- No gamified language.
- Copy cadence follows: cue -> action -> check -> adjust.

### Copy Token Contract

`GarageFocusRoomCopy.swift` is a token/constants file only.

| Token | Default Copy | Surface |
|---|---|---|
| `focusRoomNavTitle` | `Focus Room` | Focus Room navigation title |
| `focusRoomHeaderEyebrow` | `Active Drill` | Header eyebrow |
| `focusRoomHeaderDrillPositionFormat` | `Drill {current} of {total}` | Header progress text |
| `focusRoomObjectiveLabel` | `Objective` | Primary card section label |
| `focusRoomExecutionCommandLabel` | `Execution Command` | Primary card section label |
| `focusRoomPassCheckLabel` | `Pass Check` | Primary card section label |
| `focusRoomRepTargetLabel` | `Rep Target` | Active drill card metadata or expandable drill detail |
| `focusRoomDetailRegionLabel` | `Drill Detail` | Expandable region title |
| `focusRoomDetailSetupLabel` | `Setup` | Expandable detail label |
| `focusRoomDetailCommonMissLabel` | `Common Miss` | Expandable detail label |
| `focusRoomDetailResetCueLabel` | `Reset Cue` | Expandable detail label |
| `focusRoomDetailEquipmentLabel` | `Equipment` | Expandable detail label |
| `focusRoomRailCurrentLabel` | `Current` | Drill rail status |
| `focusRoomRailUpcomingLabel` | `Upcoming` | Drill rail status |
| `focusRoomRailCompletedLabel` | `Completed` | Drill rail status |
| `focusRoomNoteAddCta` | `Add Note` | Secondary control |
| `focusRoomNoteEditCta` | `Edit Note` | Secondary control |
| `focusRoomBackCta` | `Back` | Secondary control |
| `focusRoomMarkCompleteCta` | `Mark Drill Complete` | Primary dock CTA |
| `focusRoomEnterReviewCta` | `Enter Review` | Primary dock CTA |
| `reviewHandoffNavTitle` | `Session Review` | Review screen title |
| `reviewHandoffSubtitle` | `Confirm rep outcomes to finalize.` | Review lead subtitle |
| `reviewHandoffPendingFormat` | `{remaining} drills still need rep review.` | Review readiness state |
| `reviewHandoffReadyMessage` | `Rep review complete. Ready to save.` | Review readiness state |
| `reviewHandoffAutoRouteMessage` | `All drills complete. Entering review.` | Optional handoff message |
| `reviewHandoffBackToFocusCta` | `Back to Focus Room` | Review secondary CTA |
| `reviewHandoffSaveCta` | `Save Session` | Review primary CTA |

### Copy Surface Guardrails

- Focus Room copy remains execution-first.
- Review copy remains validation-first.
- CTA verbs remain literal and functional.
- Rail labels remain status-only.
- No badges/streaks/gamified framing.

### Fallback Copy Rule

Fallback copy is allowed only when source drill detail data is genuinely missing.

"Debug-visible signal" for missing detail means:
- obvious fallback wording
- reviewable naming that makes missing mapping detectable during QA/review
- no production debug UI clutter

## 4) Failure Handling Matrix

| Area | Failure Trigger | Required Behavior | Notes |
|---|---|---|---|
| Empty routine | session has zero drill entries | Show clear empty state and provide clean return path back to Garage/routine selection | No dead-end screen |
| Missing drill detail | detail mapping absent for a drill | Show explicit fallback copy with reviewable naming; preserve `Rep Target` label where possible | Must not mask broken mapping |
| All drills already complete at Focus entry | no unresolved drills at Focus start | Route directly to Review | Optional lightweight transition message |
| Completion progression | user marks drill complete | auto-advance to next unresolved drill; if none remain, route to Review | Keeps momentum with minimal taps |
| Note flow instability | note editing triggered | open sheet-only note editor; avoid inline keyboard layout shifts | Protect dock and content stability |
| Bottom dock overlap | small viewport/safe-area pressure | preserve explicit bottom inset clearance and safe-area handling so text/controls remain visible | No hidden CTA regions |
| Review validation | incomplete rep review | keep save blocked until review completeness passes | Rep values explicit and editable only |
| Save path safety | review complete and save invoked | preserve existing record creation/save/audit/achievement path | No persistence contract changes |

## Build-Only Verification Plan

Run build verification:

```bash
xcodebuild -project LIFE-IN-SYNC.xcodeproj -scheme LIFE-IN-SYNC -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Run build-only checklist:
- Run `git diff --check`.
- Confirm all required copy tokens exist.
- Confirm exact CTA labels:
  - `Mark Drill Complete`
  - `Enter Review`
  - `Back`
  - `Add Note`
  - `Edit Note`
  - `Back to Focus Room`
  - `Save Session`
- Confirm `GarageFocusRoomCopy.swift` contains tokens/constants only.
- Confirm no SwiftData model edits.
- Confirm no persistence contract edits.
- Confirm no module-boundary/global-state changes.
- Confirm no unrelated Garage screens/modules touched.

Default verification policy for this scope:
- No simulator run required.
- No screenshot QA required.
- Escalate beyond build-only only if implementation reveals a high-risk layout/safe-area regression.

## File-Scope Implementation Checklist

1. `GarageActiveSessionView.swift`
- Keep orchestration ownership.
- Route Focus entry to first unresolved drill.
- Route immediately to Review when all drills are resolved at entry.
- Preserve existing review save and persistence path.

2. `GarageFocusRoomView.swift`
- Compose Focus Room layout only.
- Accept explicit state/callback inputs from orchestration view.

3. `GarageFocusRoomHeader.swift`
- Display concise session/drill position context.
- Avoid decorative metric overload.

4. `GarageFocusDrillPrimaryCard.swift`
- Surface `Objective`, `Execution Command`, `Pass Check`.
- Surface `Rep Target` in approved placement.
- Keep deeper detail collapsed behind one expandable region.

5. `GarageFocusDrillActionDock.swift`
- Enforce single dominant CTA behavior.
- Keep secondary controls minimal and stable.

6. `GarageFocusDrillStackRail.swift`
- Show current/upcoming/completed states.
- Allow quick revisit/edit without becoming full nav chrome.

7. `GarageFocusRoomCopy.swift`
- Include approved token/constants set.
- Include `focusRoomRepTargetLabel = "Rep Target"`.
- Do not include logic/state/routing/persistence decisions.

## Explicit Non-Goals

This refactor does not include:
- SwiftData schema changes
- persistence model/contract rewrites
- app-wide navigation architecture changes
- global environment state introduction
- changes to unrelated Garage screens/modules
- gamified score/badge/streak systems
- countdown timers or forced pacing
- theatrical transitions or hype-first voice
- simulator or screenshot verification as a default requirement
