# Module Map

## Shared Shell
The shell owns:
- dashboard
- left-side module menu
- app-wide visual structure
- top-level navigation context
- summary cards and module entry points

The shell does not own module-specific workflows.

## 1. Capital Core
Purpose: personal finance tracking and financial awareness.

Owns:
- expense logging
- category summaries
- budget targets
- financial snapshots
- insights derived from local data

Does not own:
- shopping list management
- calendar scheduling
- generic task logic

V1 slice:
- add expense
- categorize expense
- view current-period spending summary
- set simple budget targets

## 2. Iron Temple
Purpose: workout planning, execution, and workout history.

Owns:
- workout templates
- planned workouts
- workout sessions
- performance history

Does not own:
- general habit tracking
- medical or injury diagnosis
- broad nutrition platform features

V1 slice:
- create workout template
- start and complete a workout
- review recent sessions

## 3. Garage
Purpose: golf swing records, review, and analysis workflow.

Owns:
- swing imports or captures
- swing metadata
- swing review records
- coaching notes
- progress journal

Does not own:
- generic media management
- unsupported biomechanics certainty
- real-time live coaching guarantees

V1 slice:
- import or register a swing clip
- attach notes and tags
- track review history

## 4. Habit Stack
Purpose: recurring daily and weekly behaviors.

Owns:
- recurring habits
- streaks
- count-based progress
- timer-based habit sessions

Does not own:
- one-off tasks
- calendar event management
- workout system depth

V1 slice:
- create habit
- mark progress
- view streak and recent completion

## 5. Task Protocol
Purpose: one-time actionable work.

Owns:
- tasks
- priority
- due dates
- completion state

Does not own:
- recurring habit rules
- long-range calendar planning
- full project management systems

V1 slice:
- add task
- complete task
- filter by status or urgency

## 6. Calendar
Purpose: time-based planning and daily agenda.

Owns:
- events
- scheduled blocks
- dated reminders
- agenda views

Does not own:
- full task ownership
- habit logic
- journaling depth

V1 slice:
- create event
- view daily agenda
- link a task deadline into calendar context

## 7. Bible Study
Purpose: scripture-focused study, notes, and reflection.

Owns:
- study sessions
- passages
- notes
- saved study history

Does not own:
- theology authority claims
- generic coaching outside scripture context

V1 slice:
- create study entry
- save passage and notes
- review study history

## 8. Supply List
Purpose: shopping capture and purchase tracking.

Owns:
- shopping items
- categories
- purchased state

Does not own:
- finance ownership
- pantry inventory
- household stock systems

V1 slice:
- add items
- group by category
- mark purchased

## Cross-Module Rules
Allowed:
- dashboard cards deep-link into relevant module surfaces
- task deadlines can appear in calendar context
- calendar items may link back to related tasks

Not allowed by default:
- shared universal tab structures across all modules
- arbitrary deep links between unrelated modules
- module overlap that blurs ownership
