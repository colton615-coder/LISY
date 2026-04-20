# Documentation Map

- Status: active docs index
- Authority: navigation guide only, not a source of product truth
- Use when: deciding what to read first
- If conflict, this beats: nothing; follow the linked canonical docs
- Last reviewed: 2026-04-19

## Read These First
1. `docs/canonical/CANONICAL_PRODUCT_SPEC.md`
2. `docs/architecture/ARCHITECTURE.md`
3. `docs/canonical/IMPLEMENTATION_CONTRACT.md`
4. `docs/canonical/AGENT_GUARDRAILS.md`
5. `docs/plans/active/PHASE_2_ROADMAP.md`

## Fast Rules
- Canonical docs define product truth.
- Architecture defines system and module boundary law.
- The implementation contract defines stable naming and root seams.
- Active plans should be few, current, and time-bound.
- Archive docs are historical only and should not drive implementation.

## Folder Roles

### `docs/canonical/`
Authoritative product and implementation rules.

### `docs/architecture/`
Durable system guidance that supports the canonical docs.

### `docs/plans/active/`
Exactly one current roadmap or execution plan when possible.

### `docs/operations/`
Runbooks and environment workflows used as needed.

### `docs/archive/`
Historical, non-authoritative reference material.

## Authoring Discipline
- Put source-of-truth material in `docs/canonical/` only when it is intended to be authoritative.
- Put durable technical guidance in `docs/architecture/`.
- Keep `docs/plans/active/` small and current.
- Move completed or stale plans to `docs/archive/`.
- Add a clear warning banner to every archive doc.
