# Data And Persistence

## Persistence Direction
V1 is local-first.

Use local persistence for all core user data. AI and external services must be optional layers on top of the local model, not replacements for it.

## Data Principles
- user-created records live locally first
- the app should function without login
- offline use is the default expectation for non-AI flows
- AI outputs are suggestions until the user confirms an action
- destructive changes should be explicit

## Recommended Native Storage Shape
Use SwiftData for primary persistence in v1.

Suggested data groups:
- shell state
- habits and completions
- tasks and completion state
- calendar events
- shopping items
- expenses and budgets
- workouts and workout sessions
- study entries and notes
- garage swing records and annotations

## Shared Concepts
Several modules need common concepts, but shared models must stay narrow:
- `CompletionRecord`
- `Tag`
- `Note`
- `AttachmentReference`
- `DateInterval` or scheduled date metadata

Shared concepts should support modules without collapsing module ownership.

## AI Boundary
AI may help with:
- affirmations
- summaries
- suggestions
- coaching-style recommendations
- categorization proposals

AI may not:
- silently modify saved records
- invent authoritative truth in finance, health, or theology
- bypass user review for imported or generated data

## Backend Boundary
No backend is required for the app to provide core value in v1.

Backend or API usage should be limited to features that truly require it, such as:
- optional AI providers
- optional external analysis services for Garage
- future sync or backup work after local-first flows are stable

## V1 Data Priorities
Must persist:
- module records
- completion history
- streak-relevant timestamps
- user preferences needed for shell behavior

Can defer:
- sync
- conflict resolution
- collaborative state
- complex analytics pipelines
- large media processing infrastructure
