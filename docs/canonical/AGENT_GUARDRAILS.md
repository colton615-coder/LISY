# Agent Guardrails

## Purpose
This file defines how coding and planning agents must interpret the product.

Read `docs/canonical/CANONICAL_PRODUCT_SPEC.md` first before proposing features, architecture, models, or UI structure.

## Mandatory Rules
- Do not invent new top-level modules.
- Do not rename canonical modules unless the canonical spec is updated.
- Do not treat `PRD.md` as the source of truth when it conflicts with the canonical spec.
- Do not treat `life-in-sync-source.txt` as a migration requirement.
- Do not add login, cloud sync, or collaboration to v1 unless explicitly requested and the canonical spec is updated.
- Do not make AI autonomous.
- Do not allow AI to silently write user data.
- Do not merge module responsibilities for convenience.
- Do not expand Supply List into pantry or inventory management.
- Do not expand Task Protocol into full project management.
- Do not expand Garage into unsupported biomechanics claims or real-time coaching promises.

## Required Assumptions
- The app is native SwiftUI, not a web port.
- The app is local-first in v1.
- The dashboard is the root home.
- Module switching is shell-level navigation.
- Every module must preserve its own domain boundaries.

## When There Is Ambiguity
Use this decision order:
1. Follow `docs/canonical/CANONICAL_PRODUCT_SPEC.md`
2. Follow `docs/architecture/ARCHITECTURE.md`
3. Follow the supporting docs in `docs/`
4. Ignore conflicting material from `PRD.md` or `life-in-sync-source.txt`

If ambiguity remains, ask for clarification instead of inventing behavior.

## Documentation Discipline
Before proposing implementation, verify:
- the feature belongs to a canonical module
- the feature is in v1 scope or explicitly marked deferred
- the behavior does not violate AI or boundary rules

If any of those checks fail, stop and call out the conflict.
