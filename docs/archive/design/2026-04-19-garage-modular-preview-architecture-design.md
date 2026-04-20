# Garage Modular Preview Architecture Design

> [!WARNING]
> Historical document. Non-authoritative. Do not use for implementation.

## Status
Archived historical design brief from the Garage UI refactor.

## Objective
Refactor the large UI-only subcomponents currently nested inside `LIFE-IN-SYNC/GarageView.swift` into dedicated Garage-local files so they can render independently in Xcode Canvas with robust `#Preview` support.

This is a developer-experience refactor only. The module must preserve the current Garage review/results look, motion, haptics, binding behavior, and orchestration flow.

## Why This Exists
`GarageView.swift` currently owns multiple premium UI primitives that are difficult to iterate on in isolation:
- dock surfaces and wide dock buttons
- Step 2 metric grid and metric cards
- the custom playback scrubber

Because those views are nested in the main file, previewing and styling them requires loading the larger Garage parent context. That slows iteration and makes Xcode Canvas less useful for focused design work.

## Goals
- Keep the Garage module visually identical after extraction.
- Make each extracted component independently previewable in Canvas.
- Keep Garage-specific visual primitives DRY through one internal support seam.
- Reduce `GarageView.swift` to orchestration and parent composition.
- Preserve module boundaries and avoid leaking Garage-only styling into shared app layers.

## Non-Goals
- No change to Garage business logic.
- No change to view behavior, haptics, or interaction rules.
- No cross-module theming refactor.
- No redesign of the existing premium Garage visuals.
- No centralized preview-fixture file.

## Source Files In Scope
- `LIFE-IN-SYNC/GarageView.swift`
- new: `LIFE-IN-SYNC/GarageStylePrimitives.swift`
- new: `LIFE-IN-SYNC/GarageDockControls.swift`
- new: `LIFE-IN-SYNC/GarageMetricGrid.swift`
- new: `LIFE-IN-SYNC/GaragePlaybackScrubber.swift`

## Architecture Decision
Use a two-layer Garage-local UI structure:

1. `GarageStylePrimitives.swift`
   Owns the shared Garage-only visual building blocks needed by the extracted files.

2. Extracted component files
   Own the isolated UI primitives plus file-local preview fixtures and `#Preview` blocks.

This keeps visual tokens and helper surfaces centralized while keeping preview data close to the component being designed.

## File-Level Design

### 1. `GarageStylePrimitives.swift`
This file becomes the Garage-local source of truth for shared review/results styling primitives that are currently trapped inside `GarageView.swift`.

It should contain only Garage-specific UI support code that is needed across multiple Garage component files, including:
- Garage review color aliases already derived from `ModuleTheme` and `AppModule.garage.theme`
- shared shadow and stroke constants
- `GarageRaisedPanelBackground`
- `GarageInsetPanelBackground`
- `GarageImpactWeight`
- `garageTriggerImpact(_:)`
- `garageFormattedPlaybackTime(_:)`
- `GarageMetricGrade.tint`

It must not:
- own Garage business logic
- own previews
- introduce new hardcoded theme colors beyond the current extracted values
- become a grab bag for unrelated Garage logic

Access level guidance:
- use file-private only for helpers that are truly single-file
- prefer internal for primitives consumed by multiple Garage files
- keep the seam Garage-local by not moving it into shared module UI

### 2. `GarageDockControls.swift`
This file extracts the dock primitives currently nested in `GarageView.swift`:
- `GarageDockSurface`
- `GarageDockWideButton`

It must include:
- a self-contained preview section at the bottom
- local preview-only sample buttons showing both primary and secondary states
- `.preferredColorScheme(.dark)` on previews

Preview requirements:
- no dependency on `GarageView`
- preview examples should show enabled and disabled states
- preview should use the real shared styling seam from `GarageStylePrimitives.swift`

### 3. `GarageMetricGrid.swift`
This file extracts:
- `GarageStep2MetricCardLayout`
- `GarageStep2MetricGrid`
- `GarageStep2MetricCard`

It must include:
- local mock `GarageStep2MetricPresentation` values at the bottom of the file
- preview coverage for:
  - an even metric set
  - an odd metric set that exercises the capstone card path
- `.preferredColorScheme(.dark)` on previews

Behavior that must remain unchanged:
- entrance animation sequencing
- capstone-card handling when the metric count is odd
- existing typography, spacing, and grade tint presentation

### 4. `GaragePlaybackScrubber.swift`
This file extracts:
- `GaragePlaybackScrubber`

It must include:
- local preview wrappers to satisfy the `@Binding` requirement for `scrubTime`
- realistic duration/time examples
- `.preferredColorScheme(.dark)` on previews

Behavior that must remain unchanged:
- drag gesture logic
- horizontal-slop guard behavior
- accessibility adjustable actions
- elapsed and duration formatting

### 5. `GarageView.swift`
After extraction, `GarageView.swift` remains the parent orchestrator.

It should:
- continue to compose the same Garage review/results surfaces
- reference the new extracted types directly
- stop defining the extracted child components internally
- preserve existing parent state ownership and callback wiring

It should not:
- duplicate styling primitives now owned by `GarageStylePrimitives.swift`
- recreate local mock data
- change routing or persistence behavior

## Data and Dependency Flow

### Shared Style Flow
`GarageView.swift` and all extracted Garage UI files import the same Garage-local style primitives from `GarageStylePrimitives.swift`.

### Component Flow
- `GarageView.swift` passes existing state and closures into extracted components.
- `GarageDockControls.swift` remains stateless aside from button actions.
- `GarageMetricGrid.swift` owns only its current entrance animation state.
- `GaragePlaybackScrubber.swift` continues to receive state through `@Binding` and callbacks.

### Preview Flow
Each extracted file owns preview-local mock data at its bottom.
That preview data exists only to render the isolated component and must not be referenced by production views.

## Failure Handling and Guardrails
- If an extracted component currently depends on a private helper still trapped in `GarageView.swift`, move that helper into `GarageStylePrimitives.swift` only if it is visual/support-only.
- If a helper is specific to one extracted file, keep it in that file instead of bloating the shared seam.
- If a dependency is business logic rather than UI support, keep it out of the support seam and leave ownership in the existing production type.
- Preview scaffolding must not introduce alternate rendering paths in production code.

## Preview Contract
Every new extracted file must end with at least one functioning `#Preview`.

Preview rules:
- use `.preferredColorScheme(.dark)`
- keep fixtures local to that file
- satisfy bindings with `.constant(...)` or a small local state wrapper
- avoid requiring `GarageView` or unrelated parent state to render
- use real Garage theme primitives, not preview-only style forks

## Integration Notes
- The extracted types should remain in the Garage module namespace with default internal visibility unless a narrower scope still allows compilation.
- The naming of extracted files should match the component names closely to improve Canvas discoverability.
- `GarageView.swift` should retain its existing top-level previews unless they break after extraction; if so, they should be updated rather than removed.

## Verification Plan
Primary verification is compile safety plus previewability of the extracted files.

Implementation should verify:
- the Garage module still builds for the intended iOS target when local environment allows it
- `GarageView.swift` compiles after nested-type removal
- each extracted file can render in Canvas through its local `#Preview`
- no style regressions were introduced by moving helpers into the shared seam

Known local caveat:
- this machine has recent history of iOS simulator/platform drift, so preview architecture should be implemented without overclaiming simulator-backed validation if Xcode runtime support is unavailable

## Implementation Sequence
1. Move shared Garage review/results styling helpers into `GarageStylePrimitives.swift`.
2. Extract dock primitives into `GarageDockControls.swift` and add local previews.
3. Extract metric grid primitives into `GarageMetricGrid.swift` and add local previews.
4. Extract scrubber into `GaragePlaybackScrubber.swift` and add local previews.
5. Remove the moved definitions from `GarageView.swift` and reconnect references.
6. Run targeted compile/build checks if the local Xcode environment permits them.

## Acceptance Criteria
- `GarageView.swift` no longer contains the extracted dock, metric-grid, or scrubber implementations.
- The extracted files compile as part of the Garage module without behavioral regression.
- `GarageStylePrimitives.swift` is the single Garage-local source of truth for shared styling primitives used by the new component files.
- Every extracted file has a functioning dark-mode `#Preview`.
- Preview mock data remains local to each extracted file.
- No Garage business logic or persistence behavior changes as part of this phase.
