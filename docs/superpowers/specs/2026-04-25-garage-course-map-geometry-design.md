# Garage Course Map Geometry Repair Design

Date: 2026-04-25
Status: approved
Scope: `LIFE-IN-SYNC/Garage/GarageCourseMapView.swift`

## Problem

`GarageCourseMapView` previously let HUD chrome participate in layout through safe-area-driven structure. That made the canvas geometry vulnerable to header and dock height, so `imageRect` could be calculated from a reduced box instead of the full spatial surface.

The course map must behave as a spatial instrument. The map image, pins, calibration handles, tap gestures, and drag gestures must all share one full-screen coordinate space.

## Approved Direction

Keep the dynamic map image inside `courseCanvas(proxy:)`.

This preserves encapsulation because `GarageCourseCanvasSurface`, `GarageCourseCanvasOverlays`, tap handling, drag handling, and `imageRect` all stay tied to the same root `GeometryProxy`.

## Considered Approaches

1. Recommended: root `GeometryReader` passes the full proxy into `courseCanvas(proxy:)`.
   This gives `courseCanvas` full-screen dimensions and keeps image rendering plus overlays in one coordinate space.

2. Rejected: render the map image in the parent `ZStack` and render overlays in `courseCanvas`.
   This splits rendering from interaction math and risks duplicated or divergent aspect-fit calculations.

3. Rejected: keep `courseCanvas` as an internal `GeometryReader` and only remove `.safeAreaInset`.
   This is better than the broken state, but it does not make the full-screen geometry contract explicit enough.

## Target Structure

`GarageCourseMapView.body` will use a root `GeometryReader`:

```swift
GeometryReader { proxy in
    ZStack {
        courseCanvas(proxy: proxy)
            .ignoresSafeArea()

        VStack(spacing: 0) {
            topStrip
                .padding(.top, proxy.safeAreaInsets.top)

            Spacer()

            bottomDock
                .padding(.bottom, proxy.safeAreaInsets.bottom)
        }
        .ignoresSafeArea()
    }
}
.background(Color.black.ignoresSafeArea())
```

The HUD remains visually safe-area-aware, but it no longer changes the canvas bounds.

## Image Rect Contract

`courseCanvas(proxy:)` will calculate `imageRect` from the raw root `proxy.size`.

The existing helper can remain:

```swift
let imageRect = garageAspectFitRect(container: proxy.size, aspectRatio: canvasAspectRatio)
```

This is valid because `canvasAspectRatio` is derived from the real map dimensions and the passed proxy is the full available spatial canvas.

Every spatial operation must use that same `imageRect`:

- `GarageCourseCanvasSurface(imageRect:)`
- `GarageCourseCanvasOverlays(rect:)`
- `handleCanvasTap(_:in:)`
- `handleCanvasDragChanged(_:in:)`
- `handleCanvasDragEnded(_:in:)`

## Non-Goals

This repair will not change SwiftData models, persistence helpers, active session resolution, shot save behavior, calibration save behavior, or `GarageCourseMapOverlayModel`.

This repair will not replace the dynamic map image with a placeholder asset.

This repair will not alter shot sequencing, calibration anchors, or normalized coordinate value types.

## Implementation Boundaries

Only the root body layout and `courseCanvas` signature should change.

The old `courseCanvas` computed property should become:

```swift
@ViewBuilder
private func courseCanvas(proxy: GeometryProxy) -> some View
```

The inner `GeometryReader` inside `courseCanvas` should be removed so there is exactly one geometry authority for the map screen.

The canvas `ZStack` should be explicitly framed to `proxy.size` so gesture locations and overlay placement remain in the same coordinate system:

```swift
.frame(width: proxy.size.width, height: proxy.size.height)
```

## Verification

Run:

```sh
git diff --check
xcodebuild -scheme LIFE-IN-SYNC -destination 'generic/platform=iOS Simulator' build
```

Manual visual verification should confirm that the map image is not vertically compressed by the HUD and that taps, drags, pins, and calibration handles remain aligned to the visible aspect-fitted image.

## Self-Review

The design has no placeholder implementation sections.

The design keeps the dynamic image inside `courseCanvas(proxy:)`, matching the approved direction.

The design preserves SwiftData and overlay model behavior.

The design identifies one geometry authority: the root full-screen `GeometryProxy`.
