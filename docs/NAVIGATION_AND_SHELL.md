# Navigation And Shell

## Primary Navigation Model
The dashboard is the root home screen.

The app exposes a persistent top-level entry point for the left-side module menu. Module switching is always a shell-level action, not a deep content action.

## Shell Responsibilities
- render dashboard home
- host module entry points
- provide stable top-level navigation
- keep module transitions coherent
- display module summaries on the dashboard

## Module Navigation
Each module may have its own internal navigation pattern, but the shell rules remain fixed:
- the module menu remains available
- deeper flows stay inside the current module by default
- module identity can change styling, but not navigation law

## Native V1 Recommendation
Use a three-layer navigation model:

1. App shell
2. Current module root
3. Module detail flow

Recommended SwiftUI shape:
- one root shell view
- one app-level selected module state
- one navigation stack per module root when depth is needed

## Dashboard Role
The dashboard is not a dumping ground. It should show:
- today overview
- upcoming tasks and events
- habit progress
- selected module summaries
- fast entry into frequently used actions

The dashboard should not attempt to replace module detail screens.

## Cross-Module Handoffs
Allowed handoffs should be explicit:
- a task with a due date can open calendar context
- a calendar item can open related task detail
- dashboard cards can jump into meaningful module destinations

If a handoff does not have a clear ownership reason, it should not exist.

## V1 Shell UX Principles
- fast launch
- low-friction movement between modules
- one stable mental model
- native-feeling transitions
- consistent structure with module-specific visual tone

## Deferred Decisions
These should be validated after the first shell prototype:
- whether module-local tabs are needed in every module
- whether the dashboard should support customization in v1
- whether iPad uses a persistent sidebar while iPhone uses a slide-out menu
