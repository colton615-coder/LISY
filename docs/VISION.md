# LIFE IN SYNC Vision

## Purpose
LIFE IN SYNC is a personal life operating system for one user on their own device.

The app organizes daily life into a shared shell with focused modules for money, fitness, habits, tasks, planning, study, shopping, and golf improvement.

## Product Direction
- Native-first SwiftUI app
- Local-first data model in v1
- No account system in v1
- Offline-first for all non-AI features
- AI is advisory only and never writes user data without explicit confirmation
- One coherent app shell with distinct module atmospheres

## Canonical Structure
`ARCHITECTURE.md` is the source of truth for app structure and boundaries.

`PRD.md` is treated as a feature pool and UX reference, not as the final architecture.

`life-in-sync-source.txt` is treated as source inspiration from a prior web implementation, not as a migration spec.

## V1 Goal
Ship a usable native shell with the full module map present and a strong first slice of the highest-value daily workflows:
- dashboard
- habits
- tasks
- calendar
- supply list
- capital core
- iron temple
- bible study
- garage

Not every module needs full depth in v1, but every module should have a clear home, a defined purpose, and at least one meaningful user flow.

## V1 Success Criteria
- The app opens into a stable dashboard shell
- Users can navigate between all modules without confusion
- Core data is stored locally and survives relaunch
- Habit, task, calendar, and shopping flows are functional offline
- Capital Core and Iron Temple support practical manual logging in v1
- Garage supports local capture/import records and review-ready metadata, even if advanced analysis is deferred
- AI usage is optional, explicit, and isolated behind user actions

## Explicit Non-Goals For V1
- Multi-user collaboration
- Cloud sync
- Real-time coaching promises
- Fully autonomous AI planning or editing
- Deep project management features
- Pantry or inventory system beyond a shopping list
- Medical, financial, or theological authority claims
