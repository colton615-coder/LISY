# ARCHITECTURE

- Status: active architecture reference
- Authority: highest technical boundary document after the canonical product spec
- Use when: deciding structure, routing, module ownership, persistence, or Garage analysis rules
- If conflict, this beats: plans, briefs, runbooks, and archived design documents
- Last reviewed: 2026-04-19

## Fast Truth
- Build one native SwiftUI app with one shared shell and eight module roots.
- Keep SwiftData and local files as the primary data layer for v1.
- Offline-first is the default for non-AI behavior.
- Dashboard summarizes and routes; modules own their operational surfaces.
- Garage analysis is on-device, deterministic, and 2D-first in the current codebase.
- AI is a translation and assistance layer, never the primary measurement engine.
- Trust is a first-class architecture concern: weak evidence must degrade or refuse cleanly.
- Use one design system with module-local atmosphere, not ad hoc module-specific UI laws.

## 1. Architecture intent
This app is a single-user personal life operating system built in SwiftUI.

The architecture must support:
- one shared app shell
- eight distinct modules
- local-first persistence
- selective backend/API use where justified
- module-specific visual identity with one consistent system structure
- safe AI boundaries

The architecture must avoid:
- feature overlap without boundaries
- silent AI writes into user data
- overbuilt support modules
- module-specific architecture drift

## 2. Core architecture principles
- Local-first in v1
- No account or login in v1
- Offline-first for non-AI features
- Shared shell, independent modules
- One design system, different module atmospheres
- AI is advisory unless explicitly confirmed by the user
- Flagship modules receive deeper systems than support modules

## 3. UI architecture / design system law
- Shared theme tokens, spacing, typography, and surface rules must anchor the UI.
- Modules may express atmosphere, but must not invent incompatible interaction laws.
- Premium surfaces should rely on layered materials, tactile depth, subtle inset/raised treatment, and restrained motion.
- Electric cyan should mark primary cues, active state, or trust-critical emphasis rather than broad decoration.
- Avoid default `List`, `Form`, or flat grouped-system styling on flagship module surfaces when a custom module surface exists.
- Shell-level navigation and hierarchy should stay visually consistent even as module mood changes.

## 4. Shell and routing contract
- Dashboard is the root home screen.
- Shell navigation owns module switching through the left module menu.
- The module menu must remain accessible from dashboard and from inside modules.
- Module switching is always a shell-level action.
- Navigation is three-layer by default:
  1. app shell
  2. module root
  3. module detail flow
- Modules keep deep navigation inside their own boundaries unless a deliberate ownership handoff exists.
- Dashboard is a summary lens and launcher; it must not replace module detail workflows.

Allowed handoffs:
- Task ↔ Calendar scheduling context
- dashboard cards launching meaningful module destinations

Disallowed by default:
- arbitrary deep links between unrelated modules
- universal shared tabs across all modules
- architecture drift that blurs module ownership

## 5. App topology
The app contains:
- one root app entry
- one shared shell
- one dashboard home
- one global slide-out module menu
- eight feature modules
- shared persistence and utility services
- optional AI and backend services

High-level shape:

```md
App
├── Shell
│   ├── Dashboard
│   ├── Module Menu
│   └── Global Navigation Context
├── Shared
│   ├── Design System
│   ├── Persistence
│   ├── Utilities
│   └── Service Layer
└── Modules
    ├── CapitalCore
    ├── IronTemple
    ├── Garage
    ├── HabitStack
    ├── TaskProtocol
    ├── Calendar
    ├── BibleStudy
    └── SupplyList
```

## 6. Module boundary law

### Capital Core
Owns:
- expense logging
- budgeting
- financial summaries

Does not own:
- shopping list inventory
- calendar planning
- generic task management

Current supported depth:
- baseline v1 depth

Must not imply:
- authoritative financial advice

### Iron Temple
Owns:
- workout generation
- workout planning
- workout execution
- workout history

Does not own:
- habits in general
- medical diagnosis
- nutrition platform scope in v1

Current supported depth:
- baseline v1 depth

Must not imply:
- medical authority or injury-safe guarantees

### Garage
Owns:
- swing capture and import
- analysis qualification and import state
- deterministic 2D swing analysis
- manual review and checkpoint review
- overlays, notes, coaching presentation, and review history

Does not own:
- generic media library
- real-time coaching promises
- unsupported biomechanics certainty

Current supported depth:
- baseline module depth with deeper Phase 2-ready analysis and review systems

Must not imply:
- unsupported 3D certainty
- fabricated confidence when evidence is weak
- confident conclusions when the review state requires reanalysis

### Habit Stack
Owns:
- recurring behaviors
- checkmark habits
- quantity habits
- focused timer habits
- streaks

Does not own:
- one-time tasks
- calendar event planning
- workouts as a whole system

Current supported depth:
- high v1 depth

Must not imply:
- project management ownership

### Task Protocol
Owns:
- one-off tasks
- priority
- deadlines
- completion state

Does not own:
- recurring habit logic
- long calendar planning
- full project management complexity

Current supported depth:
- high v1 depth

Must not imply:
- full project-management platform scope

### Calendar
Owns:
- time-based plans
- events
- deadlines
- daily agenda view

Does not own:
- full task logic
- habit logic
- deep journaling

Current supported depth:
- high v1 depth

Must not imply:
- ownership over task or habit data models

### Bible Study
Owns:
- passage study
- question/answer flow
- notes
- study history

Does not own:
- theology authority claims
- broad life coaching outside scripture context

Current supported depth:
- baseline v1 depth

Must not imply:
- final interpretive authority

### Supply List
Owns:
- shopping items
- category grouping
- purchased state

Does not own:
- budgeting logic
- pantry or inventory complexity in v1

Current supported depth:
- high v1 depth

Must not imply:
- pantry or inventory-management scope

## 7. State management strategy
- Prefer SwiftUI with feature-scoped MVVM-style state or tightly coupled view-state wrappers.
- Keep app-level state narrow: selected module, shell/menu state, shared theme context, and small routing aids.
- Let each module own its own screen state, drafts, selections, filters, and session state.
- Do not centralize the app into one giant global environment object.

Temporary runtime state examples:
- Iron Temple workout session
- Habit Stack focused timer session
- Garage analysis session and review session
- Capital Core audit flow state

## 8. Persistence architecture
- Persist core user data locally first.
- Use SwiftData for primary structured persistence in v1.
- Use local file storage only where heavier assets are required.
- Backend persistence is optional and must not become the only source of truth for core local flows.

Recommended local persistence by module:
- Capital Core: expenses, categories, budgets, financial summaries
- Iron Temple: workout templates, sessions, history, preferences
- Garage: swing records, derived analysis payloads, notes, media references, review state
- Habit Stack: habit definitions, completion history, timer totals, streak state
- Task Protocol: tasks, notes, priorities, due dates, completion state
- Calendar: events, plans, deadlines, agenda entries
- Bible Study: passages, questions, notes, study history
- Supply List: items, categories, purchased state, recent history

## 9. Backend and AI service strategy
No backend is required for:
- shell navigation
- dashboard aggregation
- local persistence flows
- current Garage deterministic analysis and review pipeline

Optional external services may support:
- AI-generated content across modules
- future Garage enrichment or remote processing if explicitly introduced later

Rule:
- the app must remain functional for local features when external services are unavailable

## 10. AI architecture
AI is a service layer, not the source of truth for everything.

Global AI rules:
- AI may generate drafts, plans, summaries, categorization, and explanations
- AI must not silently overwrite user data
- user confirmation is required before AI-created output becomes saved structured data
- AI failures must degrade gracefully
- saved user records must remain accessible without AI availability

Module AI responsibilities:
- Capital Core: audit assistance, summaries, advisory observations
- Iron Temple: workout plan suggestions and substitutions
- Garage: explain measured findings, translate metrics into coaching language, map findings into curated drills
- Bible Study: explain passages, summarize themes, support reflection
- Supply List: categorize messy item input without inventing items

Garage-specific AI rule:
- AI is not the primary measurement engine
- AI must remain traceable and refusal-capable when evidence is weak

## 11. Garage analysis architecture
Garage uses a stricter analysis pipeline than the rest of the app.

Required pipeline:
1. user captures or imports swing evidence
2. qualification logic determines whether review depth is supported
3. deterministic on-device 2D analysis extracts measurable signals
4. structured findings, checkpoints, anchors, and overlays are produced
5. review availability is surfaced honestly: ready, needs reanalysis, missing video, or unavailable
6. AI may translate supported findings into plain-English coaching and drill framing
7. user decides whether to retain, reanalyze, or discard the record

Trust rules:
- do not send raw video to an LLM and pretend that is measurement
- do not imply 3D or segment-level certainty until the stack proves it
- overlays must degrade honestly when pose confidence is weak
- unsupported conclusions must be refused, not softened into confident language
- recommendations must trace back to supported findings

## 12. Dashboard aggregation architecture
Dashboard is a summary lens, not the full operational surface of each module.

Dashboard may show:
- Capital Core summary
- Habit streak progress
- task urgency
- today’s calendar items
- workout prompt or recent workout
- Garage latest analysis snapshot
- Bible Study cue
- Supply List quick count

Dashboard rule:
- only summaries and launch surfaces belong here
- do not recreate full module workflows on dashboard cards

## 13. Error handling law
- Non-critical failures should not crash the app.
- AI or network failures must show fallback states.
- Empty states must exist for every module.
- Partial data availability should still render usable UI.
- Garage must model explicit local review and analysis states such as:
  - idle
  - importing
  - analyzing
  - ready
  - needs reanalysis
  - missing video
  - failed

## 14. Safety and trust boundaries

### Capital Core
- no false financial-advisor authority
- suggestions must be framed as guidance

### Iron Temple
- no medical claims
- no injury-safe promises
- no unhealthy body-pressure mechanics

### Garage
- no exaggerated confidence when signal quality is weak
- metrics and confidence must be transparent
- coaching must trace back to supported findings
- the product must be allowed to refuse unsupported conclusions

### Bible Study
- no claims of final interpretive authority
- support study, not replacement of discernment

## 15. Recommended folder guidance
Prefer a structure that keeps shared systems separate from module-owned code:

```md
App/
Shell/
Shared/
  DesignSystem/
  Models/
  Persistence/
  Services/
  Utilities/
Modules/
  CapitalCore/
  IronTemple/
  Garage/
  HabitStack/
  TaskProtocol/
  Calendar/
  BibleStudy/
  SupplyList/
```

## 16. Non-negotiable architecture rules
- one shared shell
- local-first core
- no silent AI writes
- module boundary discipline
- dashboard summarizes, modules operate
- support modules stay tighter than flagship modules
- Garage uses measured analysis first and coaching interpretation second
