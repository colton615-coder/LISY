# Phase 2 Roadmap

- Status: active roadmap
- Authority: current execution roadmap, not canonical product truth
- Use when: choosing near-term implementation priorities after the Phase 1 foundation
- If conflict, this beats: older plans and design briefs, but not canonical docs
- Last reviewed: 2026-04-19

## Summary
Phase 2 focuses on tightening the native product around the current shared shell, local-first model, and Garage analysis systems that already exist. The goal is not to reopen foundation work. The goal is to refine trust, polish, and depth on top of a stable SwiftUI + SwiftData base.

## Confirmed Starting State
- The app is synced and operating from the native SwiftUI codebase.
- Shared shell, dashboard, module routing, and local persistence already exist.
- Garage already has deterministic on-device 2D analysis, keyframes, overlays, review surfaces, and reanalysis handling.
- Documentation has been reset so active work can follow the canonical docs cleanly.

## Phase 2 Priorities

### 1. Canonical consistency
- Keep product and architecture docs in lockstep with the codebase.
- Do not let temporary briefs or stale plans reintroduce web-era assumptions.
- Treat context hygiene as a feature: fewer active docs, clearer authority.

### 2. Garage trust and review refinement
- Preserve measured-analysis-first behavior.
- Improve Garage review clarity, coaching presentation, and fallback honesty without overstating certainty.
- Keep deterministic checkpoint review, overlays, and manual correction flows central to the module.

### 3. Premium native UI polish
- Push flagship surfaces toward a darker, more tactile, more intentional native feel.
- Use electric cyan sparingly on primary cues.
- Favor restrained motion, clearer hierarchy, and less generic system chrome.

### 4. Dashboard and shell discipline
- Keep dashboard useful, fast to scan, and summary-oriented.
- Improve module entry clarity without recreating module workflows at the shell layer.
- Preserve stable shell navigation while module surfaces deepen.

### 5. AI boundary discipline
- Keep AI optional and user-controlled.
- Use AI to translate, summarize, and guide rather than to invent unsupported facts.
- Require explicit user confirmation for any AI-created saved output.

## Immediate Execution Filters
- Prefer changes that improve trust, review clarity, and polish without reopening architecture.
- Do not broaden scope into cloud sync, collaboration, web compatibility, or unsupported biomechanics claims.
- When a choice exists between decorative novelty and useful native behavior, choose useful behavior.

## Acceptance Shape
Phase 2 work should leave the repo in a state where:
- canonical docs still match implementation reality
- Garage remains deterministic, local-first, and honest about confidence
- flagship UI surfaces feel premium without drifting from the shared system
- the active documentation set remains compact and easy for humans or agents to load
