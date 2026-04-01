# LIFE IN SYNC Canonical Product Spec

## Status
This document is the single source of truth for the product scope of the native app.

If any document conflicts with this file, this file wins.

## Product Definition
LIFE IN SYNC is a native SwiftUI personal life operating system for one user on one device.

It is a local-first app with a shared shell and distinct modules for specific life domains.

## Platform Definition
- Primary target: iPhone
- Technology direction: SwiftUI + SwiftData
- Persistence direction: local-first
- Connectivity expectation: offline-first for all non-AI features
- Account requirement in v1: none

## Canonical App Structure
The app consists of:
- one root app entry
- one shared shell
- one dashboard home
- one module menu
- eight modules

## Canonical Modules
These names are fixed and should be used consistently in documentation and code:
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

## What The App Is
The app is:
- a personal organization system
- a modular daily operating system
- a local record of the user’s habits, tasks, plans, finances, workouts, study, shopping, and golf practice

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

### Iron Temple
Owns:
- workout templates
- workout sessions
- workout history

Does not own:
- general habits
- medical guidance
- nutrition platform depth

### Garage
Owns:
- golf swing records
- swing media references
- swing notes
- review history

Does not own:
- generic media library scope
- unsupported biomechanics certainty
- real-time coaching guarantees

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

### Bible Study
Owns:
- study entries
- passages
- notes
- study history

Does not own:
- theology authority claims
- generic life coaching outside scripture study

### Supply List
Owns:
- shopping items
- categories
- purchased state

Does not own:
- budgeting ownership
- inventory or pantry systems

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
- see today-oriented summary
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
- register or import swing record
- attach tags or notes
- review swing history

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

AI may not:
- silently create, update, or delete user records
- present speculation as authoritative truth
- bypass explicit user confirmation

## Cross-Module Truth
Allowed:
- dashboard to module entry
- task deadline into calendar context
- calendar item back to related task context

Disallowed by default:
- arbitrary deep links between unrelated modules
- shared global tabs across all modules
- moving ownership of one domain into another module for convenience

## Source Hierarchy
Use documents in this order:
1. `docs/CANONICAL_PRODUCT_SPEC.md`
2. `ARCHITECTURE.md`
3. files in `docs/`
4. `PRD.md`
5. `life-in-sync-source.txt`

If lower-priority material conflicts with higher-priority material, ignore the lower-priority material.

## Change Control
Any change to:
- top-level modules
- v1 scope
- ownership boundaries
- AI behavior rules
- local-first policy

must be made in this file first before code or secondary docs are updated.
