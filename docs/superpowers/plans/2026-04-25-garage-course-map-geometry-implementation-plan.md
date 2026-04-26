# Garage Course Map Geometry Repair Implementation Plan

Date: 2026-04-25
Status: ready for implementation
Design: `docs/superpowers/specs/2026-04-25-garage-course-map-geometry-design.md`
Scope: `LIFE-IN-SYNC/Garage/GarageCourseMapView.swift`

## Objective

Make `GarageCourseMapView` use one full-screen geometry authority so the visible map image, overlay pins, calibration handles, tap gestures, and drag gestures all share the same raw device-sized coordinate space.

## Constraints

- Do not change SwiftData models.
- Do not change persistence helpers.
- Do not change shot sequencing or calibration save behavior.
- Do not change `GarageCourseMapOverlayModel`.
- Do not replace the dynamic map image with a placeholder.
- Do not reintroduce `.safeAreaInset` for course-map HUD chrome.

## Implementation Steps

1. Refactor `GarageCourseMapView.body`.
   Replace the current root `ZStack` with a root `GeometryReader { proxy in ... }`.
   Inside the root proxy, keep a `ZStack` with `courseCanvas(proxy: proxy)` as the base layer and the HUD `VStack` as the overlay layer.

2. Preserve existing lifecycle and animation modifiers.
   Keep `.toolbar(.hidden, for: .navigationBar)`, existing `.animation(...)` calls, `.alert(...)`, and `.task { refreshResolvedState(...) }` on the outer view chain.

3. Move HUD safe-area handling into manual padding.
   Apply `proxy.safeAreaInsets.top` to `topStrip` and `proxy.safeAreaInsets.bottom` to `bottomDock`.
   Keep horizontal and visual spacing padding local to the HUD controls.
   The HUD `VStack` should use `.ignoresSafeArea()` so only its contents are padded inward.

4. Replace the computed `courseCanvas` property.
   Convert:

   ```swift
   private var courseCanvas: some View
   ```

   into:

   ```swift
   @ViewBuilder
   private func courseCanvas(proxy: GeometryProxy) -> some View
   ```

5. Remove the inner `GeometryReader` from `courseCanvas`.
   `courseCanvas(proxy:)` must calculate:

   ```swift
   let imageRect = garageAspectFitRect(container: proxy.size, aspectRatio: canvasAspectRatio)
   ```

   directly from the root proxy size.

6. Frame the canvas to the root proxy.
   Apply:

   ```swift
   .frame(width: proxy.size.width, height: proxy.size.height)
   ```

   to the `courseCanvas` root `ZStack` so gesture coordinates and overlay positions match the same full-screen coordinate space.

7. Preserve spatial consumers of `imageRect`.
   Pass the same `imageRect` to `GarageCourseCanvasSurface`, `GarageCourseCanvasOverlays`, `handleCanvasTap`, `handleCanvasDragChanged`, and `handleCanvasDragEnded`.

8. Protect map hit-testing.
   Ensure decorative gradients do not hit-test.
   Ensure transparent HUD spacer regions do not block taps or drags intended for the map.

## Expected Code Shape

```swift
var body: some View {
    GeometryReader { proxy in
        ZStack {
            courseCanvas(proxy: proxy)
                .ignoresSafeArea()

            LinearGradient(...)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topStrip
                    .padding(.horizontal, 16)
                    .padding(.top, proxy.safeAreaInsets.top + 8)
                    .padding(.bottom, 10)

                Spacer(minLength: 0)
                    .allowsHitTesting(false)

                bottomDock
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, proxy.safeAreaInsets.bottom + max(bottomInset - 24, 12))
            }
            .ignoresSafeArea()
        }
    }
    .background(Color.black.ignoresSafeArea())
}
```

## Acceptance Criteria

- `GarageCourseMapView.body` has exactly one root `GeometryReader` governing the map screen.
- `courseCanvas(proxy:)` receives the root proxy and has no nested `GeometryReader`.
- `imageRect` is derived from raw `proxy.size`, not safe-area-adjusted layout.
- The HUD is visually safe-area-aware but does not affect `imageRect`.
- No `.safeAreaInset` modifiers are used in `GarageCourseMapView`.
- Map tap and drag handlers still receive the same `imageRect` used for rendering.
- SwiftData and overlay-model behavior are unchanged.

## Verification Commands

```sh
rg -n "safeAreaInset|private var courseCanvas|private func courseCanvas|garageAspectFitRect\\(container: proxy.size" LIFE-IN-SYNC/Garage/GarageCourseMapView.swift
git diff --check
xcodebuild -scheme LIFE-IN-SYNC -destination 'generic/platform=iOS Simulator' build
```

## Manual QA

Open the Garage course map and verify:

- The map image is not vertically compressed by the header or dock.
- The header and dock float over the map.
- Tapping a visible map location places or selects at that visible location.
- Dragging a shot pin or calibration anchor stays aligned to the visible map image.
- Rotation or iPad-size changes preserve pin alignment against the aspect-fitted image.
