# Implementation Contract

## Purpose
This document translates the canonical product scope into implementation constraints for the native app.

If code structure or naming decisions are unclear, use this file after `docs/CANONICAL_PRODUCT_SPEC.md`.

## Implementation Priorities
Build in this order:
1. app shell
2. routing and module selection
3. SwiftData model foundation
4. dashboard scaffold
5. high-frequency modules
6. baseline depth modules
7. optional AI surfaces

## App Entry Contract
The app must have:
- one root app type
- one shared root shell view
- one app-level selected module state
- one SwiftData container for v1 local persistence

Recommended first concrete types:
- `LifeInSyncApp`
- `AppShellView`
- `DashboardView`
- `ModuleMenuView`

## Canonical Module IDs
Use one canonical enum for top-level navigation.

Recommended enum cases:
- `dashboard`
- `capitalCore`
- `ironTemple`
- `garage`
- `habitStack`
- `taskProtocol`
- `calendar`
- `bibleStudy`
- `supplyList`

Do not add additional top-level cases in v1.

## Module Root View Contract
Each top-level module should have one root screen with a stable name.

Recommended root view names:
- `DashboardView`
- `CapitalCoreView`
- `IronTempleView`
- `GarageView`
- `HabitStackView`
- `TaskProtocolView`
- `CalendarView`
- `BibleStudyView`
- `SupplyListView`

These are module roots, not full feature inventories.

## Shell Layout Contract
The shell must provide:
- a dashboard home state
- module switching
- a persistent path back to the module menu
- a stable content area for the selected module

The shell should not:
- embed deep feature logic
- contain per-module business rules
- force one shared tab system across all modules

## Navigation Contract
Use a layered structure:
1. shell-level selected module
2. module root view
3. module-specific navigation for detail flows

Recommended rule:
- shell navigation decides which module is visible
- module navigation decides depth within the selected module

## Model Contract
Start with module-owned models and only a few shared concepts.

Recommended first-pass model names:

Shared:
- `CompletionRecord`
- `TagRecord`
- `NoteRecord`

Habit Stack:
- `Habit`
- `HabitEntry`

Task Protocol:
- `TaskItem`

Calendar:
- `CalendarEvent`

Supply List:
- `SupplyItem`

Capital Core:
- `ExpenseRecord`
- `BudgetRecord`

Iron Temple:
- `WorkoutTemplate`
- `WorkoutSession`

Bible Study:
- `StudyEntry`

Garage:
- `SwingRecord`

These names should be treated as the implementation baseline unless a strong reason is documented before changing them.

## Dashboard Contract
The dashboard should only aggregate and route.

It may show:
- today summary
- upcoming tasks
- upcoming events
- habit progress summary
- module entry cards

It should not become:
- a full replacement for module screens
- a hidden home for module-specific editing flows

## V1 Module Depth Contract
High-frequency modules receive the first real depth:
- Habit Stack
- Task Protocol
- Calendar
- Supply List

Baseline modules receive thin but real flows:
- Capital Core
- Iron Temple
- Bible Study
- Garage

## AI Contract
AI should not shape the initial architecture.

Do not create AI-dependent core flows during the first implementation pass.

AI surfaces, if added later, must:
- be optional
- be user-triggered
- never silently write user records

## First Implementation Slice
The first code slice should deliver:
- a real app shell
- canonical module enum
- dashboard root
- module menu
- placeholder root views for all modules
- SwiftData container setup

This slice is complete when:
- the template app is gone
- every canonical module is reachable
- naming matches the canonical spec
- the project has a stable foundation for feature work

## Change Discipline
Before changing:
- module IDs
- root view names
- baseline model names
- shell structure

update this file or the canonical product spec first.
