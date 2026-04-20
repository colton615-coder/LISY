# LIFE IN SYNC Canonical Product Spec

- Status: active canonical product reference
- Authority: highest product source of truth for the native app
- Use when: deciding scope, module ownership, UX truth, or AI boundaries
- If conflict, this beats: every non-canonical document in the repo
- Last reviewed: 2026-04-19

## Fast Truth
- LIFE IN SYNC is a native SwiftUI + SwiftData app for one user on one device.
- The product is local-first and offline-first for non-AI behavior.
- The app has one shared shell, one dashboard home, one module menu, and eight modules.
- Dashboard summarizes and routes; modules own their real workflows.
- AI is optional, advisory, and never allowed to silently write user data.
- Garage is measured-analysis-first: deterministic on-device 2D analysis, then optional coaching interpretation.
- Flagship surfaces should feel dark, tactile, and premium, not like default system scaffolding.
- If a lower-priority doc implies web, cloud-first, or unsupported biomechanics certainty, ignore it.

## Product Definition
LIFE IN SYNC is a native SwiftUI personal life operating system for one user on one device.

It is a local-first app with a shared shell and distinct modules for specific life domains.

## Current Product State
The codebase is in a Phase-2-ready state:
- shared shell and module structure exist
- SwiftData-backed local persistence exists
- every canonical module is represented in the app structure
- Garage already includes deterministic on-device 2D swing analysis
- Garage review already includes checkpoints, overlays, review availability states, and reanalysis handling

This document defines the product truth that Phase 2 builds on.

## Platform Definition
- Primary target: iPhone
- Technology direction: SwiftUI + SwiftData
- Persistence direction: local-first
- Connectivity expectation: offline-first for all non-AI features
- Account requirement in v1: none

## Design Truth
- The app should feel quietly premium, tool-first, and native.
- Flagship surfaces should use dark layered materials, tactile depth, and restrained motion.
- Electric cyan should emphasize primary cues, not wash secondary controls.
- Visual hierarchy should come from layout, spacing, typography, and surface depth before decorative effects.
- Avoid generic default iOS chrome on flagship module surfaces when a custom module surface is intended.

## Canonical App Structure
The app consists of:
- one root app entry
- one shared shell
- one dashboard home
- one module menu
- eight modules

## Canonical Modules
These names are fixed and must be used consistently in code and docs:
- Dashboard
- Capital Core
- Iron Temple
- Garage
- Habit Stack
- Task Protocol
- Calendar
- Bible Study
- Supply List

No additional top-level modules are part of the product truth for v1.

## Product Boundaries
The app is:
- a personal organization system
- a modular daily operating system
- a local record of habits, tasks, plans, finances, workouts, study, shopping, and golf practice

The app is not:
- a social platform
- a collaborative workspace
- a cloud-first service
- an autonomous AI agent
- a medical, financial, or theological authority

## Shell Truth
The shell owns:
- dashboard home
- top-level module switching
- stable app-wide navigation structure
- module entry points and summaries

The shell does not own:
- module business logic
- deep module workflows
- universal cross-module tabs

## Module Truth

### Capital Core
Owns:
- expenses
- categories
- budget targets
- financial snapshots

Does not own:
- shopping list ownership
- task ownership
- event ownership

Current supported depth:
- baseline v1 depth

Must not imply:
- authoritative financial advice

### Iron Temple
Owns:
- workout templates
- workout sessions
- workout history

Does not own:
- general habits
- medical guidance
- nutrition platform depth

Current supported depth:
- baseline v1 depth

Must not imply:
- medical authority or injury-safe guarantees

### Garage
Owns:
- swing capture and import
- swing records
- swing media references
- deterministic on-device 2D analysis outputs
- checkpoint review, overlays, notes, and history
- coaching feedback grounded in measured findings

Does not own:
- generic media library scope
- real-time coaching guarantees
- unsupported biomechanics certainty

Current supported depth:
- baseline v1 depth with deeper Phase 2-ready analysis and review systems

Must not imply:
- guaranteed real-time coaching
- unsupported 3D certainty
- confident conclusions when evidence quality is weak

### Habit Stack
Owns:
- recurring habits
- progress counts
- streaks
- timer-based habit sessions

Does not own:
- one-off tasks
- workouts as a full training system
- calendar ownership

Current supported depth:
- high v1 depth

Must not imply:
- general project management ownership

### Task Protocol
Owns:
- one-time tasks
- task priority
- due dates
- completion state

Does not own:
- recurrence systems
- broad project management depth
- event ownership

Current supported depth:
- high v1 depth

Must not imply:
- full project management platform scope

### Calendar
Owns:
- events
- scheduled blocks
- agenda views
- date-based planning surfaces

Does not own:
- primary task ownership
- habit ownership
- journaling platform scope

Current supported depth:
- high v1 depth

Must not imply:
- cross-module ownership of task or habit logic

### Bible Study
Owns:
- study entries
- passages
- notes
- study history

Does not own:
- theology authority claims
- generic life coaching outside scripture study

Current supported depth:
- baseline v1 depth

Must not imply:
- final interpretive authority

### Supply List
Owns:
- shopping items
- categories
- purchased state

Does not own:
- budgeting ownership
- inventory or pantry systems

Current supported depth:
- high v1 depth

Must not imply:
- pantry or inventory management depth

## V1 Scope
V1 must include:
- a working shell
- a dashboard
- navigation to every module
- local persistence
- usable first-pass flows in every module

V1 depth is highest for:
- Habit Stack
- Task Protocol
- Calendar
- Supply List

V1 baseline depth is required for:
- Capital Core
- Iron Temple
- Bible Study
- Garage

## V1 Minimum User Flows

### Dashboard
- open app
- see a today-oriented summary
- enter any module

### Habit Stack
- create habit
- log progress
- view streak or recent completion

### Task Protocol
- create task
- complete task
- filter by open or completed state

### Calendar
- create event
- view day agenda

### Supply List
- create shopping items
- group by category
- mark purchased

### Capital Core
- add expense
- categorize expense
- view current-period summary

### Iron Temple
- create workout template
- log workout session
- review recent sessions

### Bible Study
- create study entry
- save notes
- review prior entries

### Garage
- import swing evidence
- run deterministic on-device 2D analysis
- review checkpoints and overlays
- save notes and history
- reanalyze or surface fallback states honestly when review assets are missing or degraded

## Explicit V1 Exclusions
These are out of scope unless this file is updated:
- login or account systems
- cloud sync
- collaboration
- full project management
- pantry or inventory management
- advanced nutrition systems
- autonomous AI actions
- silent AI writes
- guaranteed real-time golf coaching
- advanced biomechanics claims

## AI Truth
AI is optional and advisory.

AI may:
- generate affirmations
- suggest categories, plans, or summaries
- help the user think
- translate measured Garage findings into plain-English coaching

AI may not:
- silently create, update, or delete user records
- present speculation as authoritative truth
- bypass explicit user confirmation
- replace measured analysis in Garage

## Cross-Module Truth
Allowed:
- dashboard to module entry
- task deadline into calendar context
- calendar item back to related task context

Disallowed by default:
- arbitrary deep links between unrelated modules
- shared global tabs across all modules
- moving ownership of one module into another for convenience

## Source Hierarchy
Use this order when making decisions:
1. `docs/canonical/CANONICAL_PRODUCT_SPEC.md`
2. `docs/architecture/ARCHITECTURE.md`
3. `docs/canonical/IMPLEMENTATION_CONTRACT.md`
4. supporting docs under `docs/`
5. archived docs only for historical context

## Change Control
Before changing:
- canonical module names
- top-level app structure
- AI authority rules
- explicit v1 exclusions

update this document first.
