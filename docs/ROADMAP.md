# Roadmap

## Active Planning References
- Strategic direction: `docs/PRODUCT_DIRECTION_BRIEF.md`
- Immediate execution plan: `docs/IMMEDIATE_IMPLEMENTATION_PLAN.md`

## Milestone 0: Documentation Alignment
Goal: resolve scope and architecture before implementation.

Outputs:
- vision
- module map
- navigation and shell rules
- data and persistence rules
- design-system token baseline (spacing/type/surface/color roles)
- dashboard three-zone blueprint + module composition contract
- staged roadmap

## Milestone 1: App Shell And Core Models
Goal: replace the template app with a real shell and durable local model foundation.

Scope:
- root app shell
- dashboard scaffold
- module menu
- module routing
- SwiftData container
- initial model definitions

Exit criteria:
- all modules have reachable entry points
- app launches into a coherent dashboard
- core records persist locally

## Milestone 2: Daily Utility Modules
Goal: ship the highest-frequency workflows.

Scope:
- Habit Stack
- Task Protocol
- Calendar
- Supply List

Exit criteria:
- users can manage recurring habits
- users can manage one-off tasks
- users can create and view events
- users can build and check off shopping lists

## Milestone 3: Depth Modules
Goal: add meaningful depth to the more specialized systems.

Scope:
- Capital Core
- Iron Temple
- Bible Study
- Garage baseline records flow

Exit criteria:
- expenses and budgets are trackable
- workouts can be planned and logged
- study entries can be created and reviewed
- swing records can be imported, tagged, and reviewed

## Milestone 4: Advisory Intelligence
Goal: add optional AI without breaking local-first trust.

Scope:
- daily affirmations
- suggestion flows
- summary generation
- assistant surfaces with explicit confirmation

Exit criteria:
- AI is clearly optional
- all writes remain user-confirmed
- failures degrade gracefully

## Milestone 5: Expansion
Goal: evaluate post-v1 capabilities.

Candidates:
- deeper dashboard customization
- richer analytics
- advanced Garage analysis pipeline
- backup or sync
- iPad-specific shell optimizations

## Build Order Recommendation
Implement in this order:
1. shell and navigation
2. persistence foundation
3. habits, tasks, calendar, supply list
4. capital core and iron temple
5. bible study and garage
6. AI features
