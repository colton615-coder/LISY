# 2026-04 Garage Analyzer Checkpoint

- Status: active checkpoint
- Authority: current Garage analyzer checkpoint before the Course Mapping pivot
- Use when: resuming analyzer work after the current Garage feature shift
- If conflict, this defers to: `docs/canonical/CANONICAL_PRODUCT_SPEC.md` and `docs/architecture/ARCHITECTURE.md`
- Last reviewed: 2026-04-20

## Current State
- `GarageSkeletonHUDPanel.swift` is now a dedicated HUD surface with a typed `GarageSkeletonHUDSeverity` contract and fully isolated glass styling. `GarageSkeletonOverlay.swift` owns caption/severity selection and simply feeds plain title/detail strings into the panel, which keeps overlay logic separate from presentation.
- The Phase 5 coaching pass landed the typed render-model direction in `GarageCoachingPresentation.swift`. `GarageCoachingRenderMode`, hero/snapshot/metric/action models, and detail targets now replace the older string-driven view-state drift that existed around trust, phase, and missing-data presentation.
- `GarageCoachingReportView.swift` now renders that typed presentation through a stable shell-first card stack with staged reveal, typed badges, metric grids, and metric/snapshot drill-down targets. The report is visually premium and materially cleaner than the earlier adapter-heavy version, but its deeper evidence routing is still only partially realized.
- The analyzer pipeline remains deterministic, on-device, and local-first. The canonical docs still define Garage as a measured 2D analysis system first, with coaching layered on top of measured findings. In the live code, `GarageImportCoordinator.swift` and `GarageView.swift` still preserve local review masters, pending/import recovery, and route-driven Analyzer navigation without any cloud dependency.
- Garage review state is still truth-sensitive by design: failed imports preserve the local record when possible, reviewability is gated by persisted analysis availability, and the analyzer keeps routing inside Garage rather than leaking state into the shared shell.

## Next Recommended Phase (Analyzer)
- Tie the remaining Garage analyzer surfaces to fully domain-backed scoring and reliability output end to end. The typed render models are in place; the next pass should finish removing any remaining fallback or synthetic-looking values anywhere the analyzer still summarizes score or trust.
- Promote the current drill-down foundation into real evidence navigation. Snapshot and metric taps should ultimately route into checkpoint context, reliability blockers, or phase-specific review evidence instead of stopping at a modal-only detail surface.
- Add a targeted analyzer validation pass around presentation truth. The main checks should be render-mode correctness, preview/runtime parity, and explicit missing-data behavior so trusted, review, unavailable, and provisional states cannot drift back into ambiguous UI.
- Keep the analyzer on its existing architectural rail: Garage-local state ownership, deterministic on-device measurement, and clean degradation when evidence quality is weak.
