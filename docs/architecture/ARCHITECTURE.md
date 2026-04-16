# ARCHITECTURE

## Status: active architecture reference.


## 1. Architecture intent
This app is a single-user personal life operating system built in SwiftUI.

The architecture must support:
- one shared app shell
- eight distinct modules
- local-first persistence
- selective backend/API use where required
- module-specific visual identity with one consistent system structure
- safe AI boundaries

The architecture must avoid:
- feature overlap without boundaries
- silent AI writes into user data
- overbuilt support modules
- module-specific architecture drift

## 2. Core architecture principles
- **Local-first in v1**
- **No account/login in v1**
- **Offline-first for non-AI features**
- **Selective backend use**
- **Shared shell, independent modules**
- **One design system, different module atmospheres**
- **AI is advisory unless explicitly confirmed by user**
- **Flagship modules receive deeper systems than support modules**

### 2.1 Canonical shell + routing contract (unified)
This section is the single routing/source-of-truth contract for shell and module navigation.

- Dashboard is the root home screen.
- Shell navigation owns module switching through the left module menu.
- The module menu is available from dashboard and from inside modules.
- Module switching is always a shell-level action (never buried in module detail content).
- Navigation is three-layer by default:
  1. app shell
  2. current module root
  3. module detail flow
- Modules keep detail navigation inside their own boundary unless a deliberate ownership handoff exists.
- Dashboard is a summary lens and launcher; it must not replace module detail workflows.
- Explicit cross-module handoffs are allowed only with clear ownership:
  - Task ↔ Calendar scheduling links
  - Dashboard cards launching meaningful module destinations
- Disallowed by default:
  - arbitrary deep links between unrelated modules
  - universal shared tabs across all modules
  - architecture drift that blurs module ownership
- Canonical architecture authority lives in `docs/architecture/ARCHITECTURE.md`; planning briefs may guide sequencing but must not override this contract.

## 3. App topology
The app contains:
- one root app entry
- one shared dashboard shell
- one global slide-out module menu
- eight feature modules
- shared platform services
- shared persistence layer
- selective AI/backend services

High-level shape:

```md
App
├── Shell
│   ├── Dashboard
│   ├── Left Module Menu
│   └── Global Navigation Context
├── Shared
│   ├── Design System
│   ├── Routing Helpers
│   ├── Persistence
│   ├── AI Service Layer
│   ├── Utilities
│   └── Domain Models
├── Modules
│   ├── CapitalCore
│   ├── IronTemple
│   ├── Garage
│   ├── HabitStack
│   ├── TaskProtocol
│   ├── Calendar
│   ├── BibleStudy
│   └── SupplyList
└── External
    ├── AI APIs
    └── Garage Analysis Backend
```

## 4. Module boundary law
Each module owns its own domain.

### Capital Core
Owns:
- financial audit
- expense logging
- budgeting
- money insights

Must not own:
- shopping list inventory
- calendar planning
- generic task management

### Iron Temple
Owns:
- workout generation
- workout planning
- workout execution
- workout history

Must not own:
- habits in general
- medical diagnosis
- nutrition platform scope in v1

### Garage
Owns:
- swing capture/import
- command center posture for latest score + next issue
- analysis qualification and import state
- swing analysis and manual review
- coaching feedback
- swing records
- issue threads
- journal/progress history

Garage module root uses a four-tab local navigation model:
1. **Command Center** (`hub`) — latest score + critical next action
2. **Analyzer** (`analyzer`) — import/manual review operational surface
3. **Drills** (`drills`) — scaffolded in Phase 1
4. **Photo-Map** (`range`) — scaffolded in Phase 1

Must not own:
- generic media library
- real-time coaching promises
- unsupported biomechanics certainty
- implied 3D analysis claims before the stack proves them

### Habit Stack
Owns:
- recurring behaviors
- checkmark habits
- quantity habits
- focused timer habits
- streaks

Must not own:
- one-time tasks
- calendar event planning
- workouts as a whole system

### Task Protocol
Owns:
- one-off tasks
- priority
- deadlines
- completion state

Must not own:
- recurring habit logic
- long calendar planning
- full project management complexity

### Calendar
Owns:
- time-based plans
- events
- deadlines
- daily agenda view

Must not own:
- full task logic
- habit logic
- deep journaling

### Bible Study
Owns:
- passage study
- question/answer flow
- notes
- saved study history

Must not own:
- theology authority claims
- broad life coaching outside scripture context

### Supply List
Owns:
- shopping items
- category grouping
- purchased state

Must not own:
- budgeting logic
- pantry/inventory complexity in v1

## 5. Shared shell architecture
The app shell is the controlling frame around every module.

### Shell responsibilities
- render dashboard home
- expose left slide-out navigation menu
- provide consistent top-level navigation access
- host module entry points
- maintain global visual structure
- support dashboard summaries from modules
- provide the shared module-shell scaffold for the current shell pass

### Shell rules
- all modules must feel like part of one app
- module identity changes theme/vibe, not core UX law
- shell-level navigation must remain stable even when module content changes
- dashboard is the primary home
- module shells currently use a minimal header plus a locked floating module-local dock

## 6. Navigation architecture
### Global navigation
- Dashboard is the root home screen.
- A top-left control opens the slide-out module menu.
- The module menu is available from dashboard and from inside modules.
- Module switching is a top-level navigation action.

### Module navigation
- Each module owns its own bottom tab structure.
- Different modules may have different tab counts.
- Current module shells must keep every local surface visible at once.
- Modules may push deeper screens inside their own navigation stack.
- Deeper screens stay inside that module unless a deliberate cross-module handoff exists.

### Cross-module navigation rules
Allowed examples:
- Task deadline opens or links into Calendar context
- Calendar item can open related task detail
- Dashboard cards can jump into relevant module screens

Disallowed by default:
- random deep-linking between unrelated modules
- shared tabs across all modules
- one universal home/action/review tab pattern

## 7. State management strategy
Recommended pattern:
- **SwiftUI + MVVM-style feature state**
- lightweight shared app state only where truly needed
- feature-specific view models/stores inside each module
- service injection for persistence, AI, and backend calls

### State layers
#### App-level state
Use only for:
- selected module context
- shell/menu state
- shared theme context
- dashboard refresh triggers if needed

#### Module-level state
Each module should own:
- screen state
- filters
- selection
- drafts
- feature-specific session state

#### Session state
Some modules need temporary runtime state:
- Iron Temple workout session
- Habit Stack focused timer session
- Garage analysis/upload state
- Capital Core audit flow state

### Rule
Do not use one giant global state object for the whole app.

## 8. Persistence architecture
### v1 persistence rule
Persist core user data locally first.

Recommended storage split:
- **SwiftData/Core Data** for structured app data
- local file storage only where needed for heavier assets
- backend persistence only when feature requirements justify it

### Local persistence by module
#### Capital Core
- audit responses
- financial profile
- expenses
- categories
- budgets
- saved insights
- goals

#### Iron Temple
- exercise library references
- workout plans
- generated plans
- completed sessions
- user preferences
- history

#### Garage
- analysis metadata
- result summaries
- journal entries
- progress history
- backend job references
- local references to video assets if retained

#### Habit Stack
- habit definitions
- completion history
- quantity logs
- timer totals
- streak state

#### Task Protocol
- tasks
- notes
- priority
- due dates
- completion state

#### Calendar
- plans
- events
- deadlines
- agenda entries

#### Bible Study
- saved passages
- questions
- notes
- saved AI responses
- study history

#### Supply List
- list items
- categories
- purchased state
- recent history

## 9. Backend strategy
### No backend required early for:
- Task Protocol
- Habit Stack
- Calendar
- Supply List
- most Iron Temple persistence
- most Capital Core logging

### Backend/API required early for:
- AI-generated content across modules
- Garage upload + analysis pipeline

### Hybrid architecture rule
The app must still work for local features when network/API services are unavailable.

## 10. AI architecture
AI is a service layer, not the source of truth for everything.

### AI global rules
- AI may generate drafts, plans, summaries, categorization, and explanations.
- AI must not silently overwrite user data.
- User confirmation is required before AI-created output becomes saved structured data.
- AI failures must degrade gracefully.
- Saved user records must remain accessible without AI availability.

### Module AI responsibilities
#### Capital Core
- conduct audit flow
- summarize baseline
- suggest budgets
- provide financial observations

Rule:
- advisory only
- not authoritative financial advice

#### Iron Temple
- generate workout plans
- propose substitutions
- tailor to goals/preferences

Rule:
- user must approve before save

#### Garage
- capture qualification and evidence gating
- explain measured results
- translate metrics into coaching language
- map findings into curated drills and practice plans

Rule:
- AI is not the primary measurement engine
- AI must remain traceable and refusal-capable when evidence is weak

#### Bible Study
- explain passages
- answer study questions
- summarize themes
- support reflection

Rule:
- position as study companion, not final authority

#### Supply List
- categorize messy item input
- tidy list groupings

Rule:
- do not invent items unless prompted

## 11. Garage analysis architecture
Garage is special and must use a more rigorous pipeline.

### Required pipeline
1. user captures/imports swing evidence
2. qualification logic scores whether the evidence is weak, acceptable, or structured high-quality
3. only supported claim depth is unlocked for that evidence tier
4. deterministic or structured 2D analysis extracts measurable signals
5. structured findings, bounded metrics, checkpoints, and supported overlays are returned
6. AI may translate those results into plain-English coaching and curated drill mapping
7. user chooses whether to discard, retake, save as swing record, or attach to an issue thread
8. retained results may feed journal and progress history

### Why
This creates:
- better trust
- reproducible outputs
- debuggable failures
- cleaner separation between measurement and interpretation
- explicit control over claim depth and refusal behavior

### Garage warning
Do not make a raw “send video to LLM and hope” architecture.
Do not imply 3D or segment-style analysis until the stack proves it.

## 12. Dashboard aggregation architecture
Dashboard is a summary lens, not the full operational surface of each module.

### Dashboard can show
- Capital Core summary
- Habit streak progress
- task urgency
- today’s calendar items
- workout prompt or recent workout
- Garage latest analysis snapshot
- Bible Study progress/study cue
- Supply List quick count

### Dashboard rule
Only summaries and launch surfaces belong here.
Do not recreate full module workflows on dashboard cards.

## 13. Error handling law
- Non-critical failures should not crash the app.
- AI/network failures must show fallback states.
- Empty states must exist for every module.
- Partial data availability should still render usable UI.
- Garage upload/analysis needs explicit state handling:
  - idle
  - uploading
  - processing
  - success
  - failed

## 14. Safety / trust boundaries
### Capital Core
- no false “financial advisor” authority
- suggestions must be framed as guidance

### Iron Temple
- no medical claims
- no injury-safe promises
- no unhealthy body-pressure mechanics

### Garage
- no exaggerated confidence when signal quality is weak
- metrics/confidence should be transparent
- recommendations must trace back to supported findings
- the product must be allowed to refuse unsupported conclusions

### Bible Study
- no claims of final interpretive authority
- should support study, not replace discernment

## 15. Recommended folder structure
```md
App/
Shared/
  DesignSystem/
  Models/
  Persistence/
  Services/
    AI/
    Backend/
  Utilities/
Shell/
  Dashboard/
  ModuleMenu/
  Navigation/
Modules/
  CapitalCore/
    Views/
    ViewModels/
    Models/
    Services/
  IronTemple/
    Views/
    ViewModels/
    Models/
    Services/
  Garage/
    Views/
    ViewModels/
    Models/
    Services/
  HabitStack/
    Views/
    ViewModels/
    Models/
    Services/
  TaskProtocol/
    Views/
    ViewModels/
    Models/
    Services/
  Calendar/
    Views/
    ViewModels/
    Models/
    Services/
  BibleStudy/
    Views/
    ViewModels/
    Models/
    Services/
  SupplyList/
    Views/
    ViewModels/
    Models/
    Services/
```

## 16. v1 delivery strategy
Recommended strategy:
1. build shared shell + dashboard + module menu
2. establish persistence foundation
3. implement all module entry shells
4. deepen flagship modules first
5. build support modules to disciplined depth
6. refine AI integrations
7. refine dashboard aggregation

Why:
- preserves whole-app structure
- prevents isolated overbuilding
- keeps flagship focus without losing app cohesion

## 17. Non-negotiable architecture rules
- one shared shell
- local-first core
- no silent AI writes
- module boundary discipline
- support modules stay tighter than flagship modules
- dashboard summarizes, modules operate
- Garage uses measured analysis first, AI interpretation second
