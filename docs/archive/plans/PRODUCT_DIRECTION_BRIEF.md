# Product Direction Brief (2026-04)

> [!WARNING]
> Historical document. Non-authoritative. Do not use for implementation.

## Status: archived historical direction brief.


## Purpose
This brief consolidates the latest product-direction input into implementation-ready guidance that aligns with canonical module names and architecture.

This document **extends** the existing canon; it does not replace:
- `docs/canonical/CANONICAL_PRODUCT_SPEC.md`
- `docs/architecture/ARCHITECTURE.md`

## Direction Summary
LIFE IN SYNC should behave as a **useful-first personal operating system** for one user:
- private and personal over mass-market appeal
- tool-first over lifestyle branding
- restrained, dependable, and clarity-first
- deeper systems over shallow feature breadth

## Non-Negotiable Decision Rule
When tradeoffs appear:
1. usefulness over beauty
2. usefulness over perceived intelligence

## UX and Visual Direction Additions
These are guiding constraints for implementation detail:
- Keep one coherent system language across the app shell
- Preserve distinct module identity with restrained color accents
- Convey hierarchy using layout, spacing, and typography before color/effects
- Keep confirmation and feedback quiet, fast, and predictable
- Maintain predictable navigation patterns over novelty

Design-system implementation emphasis:
- Define one spacing scale, one typography hierarchy, and explicit color-role mapping
- Use surface layering rules so modules feel distinct but still part of one system
- Keep gradients/glow effects subtle and functional (state/focus), never decorative-first
- Use motion as micro-feedback (transitions/state changes), not as spectacle

## Global Flow Additions
### Launch affirmation
A short (target ~4s) launch affirmation moment is acceptable when:
- it does not block app reliability
- it has offline-safe fallback content
- skip/reduce behavior can be introduced later if needed for speed

Recommended payload:
- app title
- logo mark
- one quote or verse

### Dashboard behavior
The dashboard should prioritize:
- progress visibility before urgency-only lists
- balanced module coverage across the full system
- quick readability with immediate jump paths into modules

Dashboard blueprint preference:
- Hero: daily focus + one key metric
- Middle: module pulse strip (cross-module status at a glance)
- Bottom: timeline + alerts (quiet, actionable, non-alarming)

Priority ranking policy:
- urgency first, then importance
- keep urgency signals subtle, not alarming

## Deep Module Architecture Additions
For deeper modules, prefer a **hub-and-spokes** structure:
- one module home/hub first
- one hero status area at top
- current state first, next actions second
- internal bottom tabs for supporting surfaces

Module screen composition preference:
1. hero summary
2. dynamic visualization block (module-specific)
3. contextual actions
4. activity/feed/history lane

Modules requiring stronger internal command-center structure:
- Garage
- Iron Temple
- Capital Core
- Bible Study
- Calendar

## AI Interaction Additions
AI remains optional and user-controlled, with this default pattern:
1. guided input
2. final recommendation
3. explicit approve/reject

Interaction expectations:
- small, subtle orb-style affordance for invocation
- compact first panel focused on input, not auto-suggestions
- contextual awareness across the current module
- no write/change/save without explicit user confirmation
- concise answer by default; deeper rationale on request

Feedback loop expectations:
- user can reject outputs with quick module-specific reasons
- system may learn preferences over time (without violating explicit-write rule)

## Data Visualization Guidance (Module-Specific)
Prefer meaningful module-native visuals instead of generic stat tiles:
- Habit Stack: streak rings, weekly heatmaps, momentum trend visuals
- Capital Core: trend graphs, clean category grids, cash-flow clarity views
- Iron Temple: performance trend stats, session log summaries, progression visuals
- Bible Study: calm text-first reading/review surfaces with minimal supportive metrics

All visualizations should optimize for decision support, not decoration.

## Tone Additions
Product voice:
- serious
- grounded
- restrained
- quietly premium

Copy rules:
- refined and intentional labels
- neutral empty states
- assistant voice: wise, calm, concise by default

## Canonical Naming Alignment
External wording like “Workouts” and “Money” should map internally to canonical module names:
- Workouts → **Iron Temple**
- Money → **Capital Core**

All implementation artifacts should keep canonical names as source-of-truth identifiers.

## Immediate Documentation and Delivery Implications
Before heavy UI polish, lock reusable architecture patterns for deep modules and AI surface behavior.

Use `docs/plans/active/IMMEDIATE_IMPLEMENTATION_PLAN.md` as the execution sequence for next steps.
