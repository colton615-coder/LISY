# Documentation Map

This directory is organized by **authority level** and **time horizon** so implementation work can quickly find the right source of truth.

## Reading Order (Start Here)
1. `docs/canonical/CANONICAL_PRODUCT_SPEC.md` (highest authority for product scope)
2. `docs/canonical/IMPLEMENTATION_CONTRACT.md` (implementation constraints and naming contracts)
3. `docs/canonical/AGENT_GUARDRAILS.md` (agent behavior guardrails)
4. `docs/architecture/ARCHITECTURE.md` (system architecture and boundary law)
5. Supporting docs in `docs/architecture/`, then active plans in `docs/plans/active/`
6. Operations docs in `docs/operations/` as needed for environment/workflow
7. Historical context in `docs/archive/` (non-authoritative)

If any lower-priority document conflicts with canonical docs, canonical docs win.

## Taxonomy

### `docs/canonical/`
Canonical, source-of-truth documentation for product scope and implementation constraints.

### `docs/architecture/`
Durable architecture and persistence guidance that supports (but does not override) canonical docs.

### `docs/plans/active/`
Active and time-bound implementation plans/direction briefs. These guide execution sequencing and near-term work.

### `docs/operations/`
Runbooks, workflows, and active operational incidents/blockers.

### `docs/archive/`
Historical context, retrospectives, and translation/reference documents retained for background.

## Authoring Discipline for New Docs
- Put long-lived source-of-truth material in `docs/canonical/` only when it is intended to be authoritative.
- Put durable technical guidance in `docs/architecture/`.
- Put time-boxed plans in `docs/plans/active/`; include date or period in title when useful.
- Put runbooks/incidents in `docs/operations/`; date incident docs.
- Move stale or completed plans to `docs/archive/` instead of leaving them as top-level peers to canonical docs.
- Prefer adding short `Status:` notes at the top of non-canonical docs.
