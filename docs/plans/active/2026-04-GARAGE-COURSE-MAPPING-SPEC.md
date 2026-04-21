# 2026-04 Garage Course Mapping Spec

- Status: active feature spec
- Authority: Garage Course Mapping implementation brief for the current Phase 2 slice
- Use when: building the first production architecture and UI flows for Course Mapping
- If conflict, this defers to: `docs/canonical/CANONICAL_PRODUCT_SPEC.md` and `docs/architecture/ARCHITECTURE.md`
- Last reviewed: 2026-04-20

## Summary
Garage Course Mapping is a local-first, interactive 2D hole reconstruction system inside Garage.

Its purpose is to give the user the feel of a premium golf tracking and insight product without live on-course GPS tracking.

The system works by reconstructing one hole at a time from either:
- uploaded course-book images or PDFs
- assisted web import from a pasted course URL such as BlueGolf

After ingest, the user calibrates the hole by placing fixed anchors on the flat hole image so Garage can apply simple spatial math to later shot placement.

Shots are then logged by tapping approximate landing locations on the calibrated hole canvas and attaching a compact tactical payload.

The first insight payoff is visual pattern review: shot pins, miss clustering, and simple tendencies rendered directly on the 2D hole map.

## Product Boundaries

### In Scope
- dual-ingest hole sourcing from uploads and assisted web import
- one calibrated hole at a time
- user-driven anchor calibration
- tap-to-place tactical shot logging
- hybrid logging workflow:
  quick on-course logging and fuller after-round debrief
- round session ownership of the reconstructed hole and shot history
- visual review of shots and tendencies on the hole canvas

### Explicitly Out of Scope
- live or continuous `CoreLocation` tracking
- autonomous background GPS sampling
- automatic real-time shot detection
- cloud-first sync requirements
- unsupported precision claims beyond rough user placement and calibrated 2D math

## Core Interaction Model

### Working Unit
The working unit is one detailed hole map at a time.

Garage should not begin with a full-round live map experience.
The user enters a round session, selects or ingests a hole, calibrates it, then logs shots on that hole canvas.

### Calibration Model
Each hole becomes spatially useful only after anchor calibration.

The required calibration anchors for MVP are:
- tee anchor
- fairway checkpoint anchor
- green center anchor

These anchors convert a flat imported hole image into a calibrated 2D tactical surface.
The calibration model is intentionally simple and user-confirmed. Garage should not imply survey-grade precision.

### Shot Logging Model
Each shot is placed by tapping a rough landing location on the calibrated map.

That landing placement is then paired with the core tactical payload:
- club selection
- shot type
- intended target
- lie before shot
- actual result
- rough landing pin

This log is designed to be fast enough for a one-handed on-course entry pass, while still supporting a fuller after-round correction pass.

### Insight Model
The first insight layer is visual, not numerical-heavy.

Garage should prioritize:
- rendered shot pins on the hole
- visible miss patterns
- simple shot tendency clustering by outcome or lie

The MVP should not overreach into advanced simulation, live caddie behavior, or unsupported statistical certainty.

## Architecture Direction

### Module Ownership
Course Mapping remains fully inside Garage.

The shared shell may route into Garage, but it must not own:
- course ingestion logic
- hole calibration logic
- round session tactical data
- shot review rendering

### Local-First Data Flow
The architecture is local-first from ingest through review.

The expected flow is:
1. acquire a hole source from upload or assisted web import
2. normalize it into a local Garage hole asset reference
3. calibrate the hole with user anchors
4. create or attach to a Garage round session
5. log tactical shots locally against the calibrated hole
6. render review overlays and visual patterns from local persisted state

Assisted web import may fetch reference data, but Garage remains the owner of the final local representation used for review.

### Trust And Precision Rule
Garage must present the hole as a calibrated tactical canvas, not as a true GPS survey map.

If a hole has not been calibrated, Garage must degrade honestly:
- allow viewing of the raw source image
- block or limit tactical placement that depends on calibration
- prompt the user to finish anchor setup before review-grade use

## SwiftData Schema

The MVP persistence model should center on three primary entities plus lightweight enums/value types.

### `GarageRoundSession`
Owns one user round or debrief session.

Required responsibilities:
- identify the course context for the session
- store session date and title
- own the ordered set of hole maps used in that round
- own the tactical shot history for the round

Suggested core fields:
- `id`
- `createdAt`
- `updatedAt`
- `sessionTitle`
- `courseName`
- `sessionDate`
- `notes`
- `holes: [GarageHoleMap]`
- `shots: [GarageTacticalShot]`

### `GarageHoleMap`
Owns one reconstructed hole inside a round session.

Required responsibilities:
- store the local asset reference for the imported hole image
- store the source provenance:
  upload or assisted web import
- store the hole identity:
  hole number, par, yardage label
- store the calibrated spatial anchors needed for 2D tactical math

Suggested core fields:
- `id`
- `createdAt`
- `updatedAt`
- `holeNumber`
- `holeName`
- `par`
- `yardageLabel`
- `sourceType`
- `sourceReference`
- `localAssetPath`
- `imagePixelWidth`
- `imagePixelHeight`
- `teeAnchor`
- `fairwayCheckpointAnchor`
- `greenCenterAnchor`
- `session: GarageRoundSession?`
- `shots: [GarageTacticalShot]`

### `GarageTacticalShot`
Owns one manually logged shot inside a session and on a specific hole.

Required responsibilities:
- store the rough landing point on the calibrated map
- store the core tactical metadata
- remain lightweight enough for rapid entry

Suggested core fields:
- `id`
- `createdAt`
- `updatedAt`
- `sequenceIndex`
- `holeNumber`
- `placement`
- `club`
- `shotType`
- `intendedTarget`
- `lieBeforeShot`
- `actualResult`
- `session: GarageRoundSession?`
- `hole: GarageHoleMap?`

## Supporting Value Types

### `GarageMapAnchor`
Typed calibration point for a hole image.

Suggested fields:
- `kind`
- `normalizedX`
- `normalizedY`

The point should be normalized to the imported image dimensions so the calibration survives different display sizes.

### `GarageShotPlacement`
Typed normalized placement for a logged shot.

Suggested fields:
- `normalizedX`
- `normalizedY`

### Suggested Enums
- `GarageHoleSourceType`
  upload image, upload PDF render, assisted web import
- `GarageTacticalClub`
  strongly typed club identity
- `GarageTacticalShotType`
  tee shot, approach, layup, recovery, chip, putt
- `GarageTacticalLie`
  tee, fairway, rough, bunker, recovery, green fringe, green
- `GarageTacticalResult`
  on target, short, long, left miss, right miss, hazard, recovery required

## UI Workflows

### 1. Ingestion And Calibration Flow
Purpose:
turn an uploaded or web-assisted source into a usable calibrated hole.

Expected flow:
1. user chooses source:
   upload or paste URL
2. Garage creates a local hole asset representation
3. Garage presents the flat hole image in a dark premium calibration workspace
4. user places tee anchor
5. user places fairway checkpoint anchor
6. user places green center anchor
7. Garage confirms the calibrated hole and enables tactical logging

UI behavior rules:
- keep the workspace focused on one image and one step at a time
- use large clear anchor handles
- active calibration state uses electric cyan
- incomplete calibration must stay visually obvious
- do not overload the screen with explanatory text

### 2. Hybrid Tactical Entry Flow
Purpose:
support both fast on-course logging and fuller after-round debrief without separate data models.

Expected flow:
1. user taps a visible primary action from the hole canvas
2. Garage presents a compact tactical entry surface
3. user taps a rough landing position on the map
4. user selects the core tactical payload through large hit targets
5. user saves the shot into the active round session

On-course mode emphasis:
- one-handed, tap-heavy entry
- minimal typing
- fast save path
- compact staged reveal rather than a long form

After-round debrief emphasis:
- revisit and refine existing shots
- add missed shots
- correct lie, result, and target details

UI behavior rules:
- present as a premium Garage instrument panel, not a generic form
- use dark layered materials and raised/inset surfaces
- reserve electric cyan for the current active choice and save-critical actions
- prioritize club, lie, and result as large tactile selections

### 3. Review Canvas
Purpose:
render the reconstructed hole as the main tactical review surface.

Expected behavior:
- show the calibrated hole image as the base canvas
- show saved shot pins over the hole
- support selection of past shots
- support visual grouping of misses and tendencies
- keep the hole as the dominant surface, with analytics secondary

UI behavior rules:
- preserve a premium dark Garage atmosphere
- treat the canvas as the hero surface
- use restrained overlays and avoid dense data walls
- keep labels short and scannable

## Visual Direction
- premium dark Garage atmosphere
- layered glass and raised/inset surfaces
- restrained motion
- electric cyan only for active calibration, active route state, and primary logging actions
- typography should feel like an instrument panel:
  crisp, compact, high-contrast, and easy to scan outdoors

## Failure Handling
- if ingest succeeds but calibration is incomplete, save the hole in an unavailable-for-logging state
- if a URL import yields weak or partial data, keep the imported asset as reference material and require manual confirmation
- if a shot is logged before full detail is known, allow the fast save path and support later refinement in after-round debrief
- if the imported image is low quality, Garage should still allow rough tactical use after calibration, but should not imply precision it does not have

## MVP Acceptance Shape
The MVP is successful when the user can:
1. create a round session
2. ingest one hole from an upload or assisted web source
3. calibrate the hole with tee, fairway checkpoint, and green center anchors
4. tap to place shots on the hole
5. save the core tactical payload for each shot
6. reopen the round later and review visible shot patterns on the calibrated 2D map

## Non-Goals For This Slice
- continuous background tracking
- battery-intensive GPS behavior
- automated shot sensing
- cloud collaboration
- advanced strokes-gained style modeling
- fully automatic course reconstruction without user confirmation
