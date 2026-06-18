# Data And Persistence

## Status: active architecture support guidance.


## Persistence Direction
V1 is local-first.

Use local persistence for all core user data. V1 does not depend on accounts, backend services, cloud sync, remote processing, or external APIs.

## Data Principles
- user-created records live locally first
- the app should function without login
- offline use is the default expectation for non-AI flows
- AI is optional, advisory, user-triggered, and confirmation-gated
- AI outputs are suggestions until the user confirms an action
- destructive changes should be explicit
- third-party packages require explicit approval

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
V1 does not include:
- account infrastructure
- backend services
- cloud sync or remote backup
- remote Garage processing
- external API dependencies for core features

Any future backend, API, cloud-sync, account, backup, or remote-analysis exception is non-v1 work and requires explicit architecture approval before implementation. A future exception must preserve local ownership, offline access to core records, visible user control, and the advisory AI boundary.

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
