# Garage Skeleton HUD Panel Design

- Status: proposed
- Scope: Garage overlay HUD only
- Authoritative for: `GarageSkeletonHUDPanel.swift` and HUD integration in `GarageSkeletonOverlay.swift`
- Does not change: skeleton path math, joint mapping, `AnimatablePair` behavior, confidence logic
- Date: 2026-04-20

## Goal

Replace the current two-piece HUD in the Garage skeleton overlay with one compact, bottom-leading, frosted instrument panel that matches the Phase 2 Garage visual language.

## Current Problem

The existing HUD in `GarageSkeletonOverlay.swift` uses:
- one black caption box for title/detail
- one separate orange capsule for consequence

This feels utilitarian and sticker-like. It breaks the premium overlay language and over-emphasizes severity through a filled pill instead of typography, iconography, and trust-bounded hierarchy.

## Approved Direction

Use one stable bottom-leading HUD panel.

Why:
- keeps the overlay anchored and easy to track during fast swing playback
- avoids body-following jitter
- preserves restrained motion
- reads as an instrument panel, not an annotation sticker

## New Component

Create a new view:

`GarageSkeletonHUDPanel`

Recommended API:

```swift
struct GarageSkeletonHUDPanel: View {
    let title: String
    let detail: String
    let severity: GarageSkeletonHUDSeverity?
}
```

Create a small UI-only severity type for the panel:

```swift
enum GarageSkeletonHUDSeverity {
    case neutral(String)
    case warning(String)
    case critical(String)
}
```

This type is presentation-only. It must not own or compute overlay state. `GarageSkeletonOverlay` remains responsible for deciding whether a severity row should appear and what label it carries.

## Visual Contract

### Container

- One `RoundedRectangle`
- Corner radius: compact and soft, approximately `14`
- Reads as a floating panel, not a card glued to the screen edge
- Compact padding to keep the panel lightweight

### Background

Layering:
- `Material.ultraThinMaterial`
- faint `Color.vibeSurface.opacity(...)` tint above the material
- faint white top-light stroke
- soft dark shadow below

The panel should feel glassy and tactile, but not bright or glowy.

### Internal Layout

Use a `VStack(alignment: .leading, spacing: 6)`:

1. Headline
- `font(.caption.weight(.semibold))`
- primary white text
- max `2` lines

2. Detail
- `font(.caption2.weight(.medium))`
- reduced-opacity white or secondary text tone
- max `2` lines

3. Inline severity row
- `HStack(spacing: 6)`
- SF Symbol on the left
- severity label on the right
- only render when severity exists

## Severity Rules

Do not use any filled capsule or block color background.

Only tint:
- icon
- severity text

Mapping:
- neutral: `exclamationmark.circle.fill` with reduced-opacity white
- warning: `exclamationmark.triangle.fill` with orange tint
- critical: `exclamationmark.triangle.fill` with red tint

Severity copy should stay short and scannable. Use the existing `consequence.riskPhrase` string as the label source unless a future Garage copy pass redefines it.

## Motion Rules

Allowed:
- `.transition(.opacity)` on the severity row
- subtle opacity-only appearance/disappearance for the whole panel if needed

Not allowed:
- positional movement
- spring entrance
- bounce
- scale pop
- body-anchored following behavior

## Integration Contract

The integration stays inside `GarageSkeletonOverlay.swift`.

Current seam:
- `GarageSkeletonOverlay.body`
- the `ZStack(alignment: .bottomLeading)` already exists
- the current HUD is the `VStack(alignment: .leading, spacing: 8)` after the `Canvas`

Replace that HUD block with:

```swift
if let captionTitle, let captionDetail {
    GarageSkeletonHUDPanel(
        title: captionTitle,
        detail: captionDetail,
        severity: hudSeverity
    )
    .padding(12)
    .transition(.opacity)
}
```

Add one small computed property in `GarageSkeletonOverlay`:

```swift
private var hudSeverity: GarageSkeletonHUDSeverity? {
    guard showsConsequence, let consequence else { return nil }
    return .warning(consequence.riskPhrase)
}
```

Notes:
- keep all state derivation in `GarageSkeletonOverlay`
- keep all view styling in `GarageSkeletonHUDPanel`
- do not push `GarageSyncFlowReport` or `GarageSyncFlowConsequence` into the new panel

## Non-Goals

- no changes to skeleton drawing math
- no changes to sync-flow timing rules
- no rewording of Garage consequence copy
- no panel repositioning logic
- no animation system overhaul

## Risks And Guards

### Risk: HUD becomes too heavy

Guard:
- keep corner radius moderate
- keep padding compact
- keep shadow soft and low-opacity
- cap detail at two lines

### Risk: Severity competes with the skeleton

Guard:
- tint only the icon and severity label
- do not introduce filled warning backgrounds
- keep the panel anchored at bottom-leading

### Risk: View-state coupling leaks into the component

Guard:
- pass plain strings and a lightweight severity enum into `GarageSkeletonHUDPanel`
- do not pass `syncFlow` or raw consequence models into the component

### Risk: Dynamic Type breaks compact layout

Guard:
- restrict the maximum dynamic type size used by the HUD text so `caption` and `caption2` remain lightweight overlay styles
- keep the panel compact enough that it does not obscure the skeleton during review

## Acceptance Check

The refactor is complete when:
- `GarageSkeletonOverlay` still draws the exact same skeleton and truth layers
- the old black caption box and orange capsule are both gone
- one frosted HUD panel appears in the bottom-leading corner
- consequence state renders as an inline severity row, not a separate pill
- HUD appearance changes use opacity-only transitions
- the new component is reusable and styling-focused

## Implementation Slice

This is one bounded UI slice:
- add `GarageSkeletonHUDPanel.swift`
- update the HUD block in `GarageSkeletonOverlay.swift`
- no broader Garage refactor
