# Implementation Contract

- Status: active canonical implementation support
- Authority: code-facing contract under the canonical product spec and architecture doc
- Use when: deciding names, root types, navigation seams, or safe implementation defaults
- If conflict, this beats: plans, briefs, and archived implementation notes
- Last reviewed: 2026-04-19

## Fast Truth
- Keep one root app type, one shared shell, one dashboard root, and eight module roots.
- Use one canonical top-level module enum and do not rename cases casually.
- Treat module roots as stable entry seams, not temporary scaffolds.
- Prefer module-owned models and narrow shared concepts.
- Dashboard aggregates and routes; it does not own deep editing flows.
- AI surfaces must be optional, user-triggered, and confirmation-gated.
- Phase 2 assumes the shell and module foundation already exist.

## App Entry Contract
The app must have:
- one root app type
- one shared root shell view
- one app-level selected module state
- one SwiftData container for local persistence

Preferred concrete types:
- `LifeInSyncApp`
- `AppShellView`
- `DashboardView`
- `ModuleMenuView`

## Canonical Module IDs
Use one canonical enum for top-level navigation.

Required cases:
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
Each top-level module should have one stable root view:
- `DashboardView`
- `CapitalCoreView`
- `IronTempleView`
- `GarageView`
- `HabitStackView`
- `TaskProtocolView`
- `CalendarView`
- `BibleStudyView`
- `SupplyListView`

These are root seams, not full feature inventories.

## Navigation Contract
Use a layered structure:
1. shell-level selected module
2. module root view
3. module-specific navigation for detail flows

Rules:
- shell navigation decides which module is visible
- module navigation decides depth inside the selected module
- do not force one universal tab system across all modules

## Model Contract
Start with module-owned models and only a few shared concepts.

Recommended shared concepts:
- `CompletionRecord`
- `TagRecord`
- `NoteRecord`

Recommended module-owned baselines:
- Habit Stack: `Habit`, `HabitEntry`
- Task Protocol: `TaskItem`
- Calendar: `CalendarEvent`
- Supply List: `SupplyItem`
- Capital Core: `ExpenseRecord`, `BudgetRecord`
- Iron Temple: `WorkoutTemplate`, `WorkoutSession`
- Bible Study: `StudyEntry`
- Garage: `SwingRecord`

Do not rename these lightly. If a rename is necessary, update this file and the canonical docs first.

## Dashboard Contract
The dashboard may show:
- today summary
- upcoming tasks
- upcoming events
- habit progress summary
- module entry cards
- Garage latest analysis snapshot

The dashboard should not become:
- a full replacement for module screens
- a hidden home for module-specific editing flows

## AI Contract
AI should not shape core architecture.

AI surfaces must be:
- optional
- user-triggered
- concise by default
- unable to silently write records

Default interaction pattern:
1. guided input
2. recommendation or explanation
3. explicit approve or reject

## Naming Translation Rule
If planning inputs use alternate language, map them to canonical names in code and docs:
- Money => Capital Core
- Workouts => Iron Temple

## Change Discipline
Before changing:
- module IDs
- root view names
- baseline model names
- shell structure

update this file or the canonical product spec first.
