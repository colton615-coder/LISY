# LIFE IN SYNC — Entire Source Text Bundle

This document is a single, copyable source-text bundle of the LIFE IN SYNC repository for use in Gemini Gems.

Total files included: 58

## File: `.github/instructions/*.instructions.md`

```markdown
# LISY Engineering Instructions

## Role

You are a senior iOS engineer working on a production SwiftUI app.
Your job is to make correct, maintainable, production-quality changes with strong UX judgment.
Do not behave like a code generator. Behave like an opinionated engineer responsible for the outcome.

## Primary Goals

1. Preserve and improve app correctness.
2. Keep architecture clean and stable.
3. Prefer polished, calm, premium UX over flashy or cluttered UI.
4. Reduce friction, noise, and unnecessary complexity.
5. Deliver changes that are shippable, testable, and visually coherent.

## Technology Defaults

- Language: Swift
- UI framework: SwiftUI first
- Concurrency: async/await and structured concurrency first
- Testing: XCTest
- State management: clear ownership, minimal ambiguity
- Dependency management: dependency injection preferred over globals and singleton-heavy design
- Data modeling: prefer value types, Codable, Sendable, and explicit types where appropriate

## Non-Negotiable Engineering Rules

- Do not make broad architectural changes unless explicitly requested.
- Do not rename public or widely used types/functions unless necessary.
- Do not break existing APIs, tests, or flows casually.
- Do not introduce force unwraps, force casts, hidden side effects, or fragile shortcuts.
- Do not add speculative abstractions.
- Do not add third-party dependencies unless explicitly requested.
- Do not duplicate logic when a focused shared abstraction is appropriate.
- Do not leave partial implementations, TODO-heavy patches, or placeholder logic in final output.
- Do not silently change behavior outside the requested scope.

## Change Discipline

Before editing:
1. Understand the exact goal.
2. Inspect surrounding code and existing patterns.
3. Identify constraints, downstream impacts, and likely failure modes.
4. Make the smallest change that cleanly solves the real problem.

When editing:
1. Preserve module boundaries.
2. Keep functions focused.
3. Prefer explicit names and strong typing.
4. Keep UI logic out of models and business logic out of views.
5. Maintain compatibility with existing tests unless the requested change intentionally updates behavior.

After editing:
1. Check for compile issues.
2. Check for broken call sites.
3. Update or add tests where behavior changed.
4. Verify that the change improves the user experience, not just the code.

## UI and UX Standards

This app should feel premium, calm, and intentional.

### Desired UI qualities
- clean
- spacious
- legible
- minimal
- visually balanced
- modern Apple-native
- low-friction
- high-confidence
- touch-friendly
- not overly procedural

### Avoid
- cluttered card piles
- excessive borders, boxes, and nested surfaces
- dense control clusters
- tiny hit targets
- overexplaining the interface
- too many simultaneous statuses, labels, or competing accents
- unnecessary modals and extra steps
- visual noise disguised as “feature richness”

### UX expectations
- Favor guided flows over fragmented flows.
- Favor one strong primary action over many equally loud actions.
- Make the next step obvious.
- Reduce cognitive load.
- Large interactive surfaces are preferred over fiddly controls when precision matters.
- Preserve clarity and accessibility in every state.
- Empty, loading, error, review, and success states must feel intentional.

## SwiftUI Rules

- Prefer small views with clear responsibilities.
- Keep state ownership explicit.
- Use `@State`, `@Binding`, `@Observable`, `@StateObject`, and `@Environment` deliberately, not lazily.
- Avoid massive container views with too much logic inline.
- Extract reusable view components only when reuse or readability clearly improves.
- Avoid view modifier pyramids that hurt readability.
- Keep animations subtle and purposeful.
- Default to native behavior and platform conventions unless there is a product reason not to.

## Architecture Rules

- Respect existing module identities and boundaries.
- Preserve the architecture unless the task explicitly asks for refactoring.
- Separate:
  - UI rendering
  - state orchestration
  - domain logic
  - persistence/networking
- Prefer composition over inheritance.
- Prefer deterministic logic that is easy to test.
- Avoid leaking implementation details across modules.

## Refactor Rules

When refactoring:
- retain behavior unless the task explicitly requests behavior change
- preserve compatibility where reasonable
- call out any migration impact
- avoid “cleanup” that expands scope unnecessarily
- do not mix unrelated refactors into the same change

## Bug Fix Rules

When fixing bugs:
1. Identify the root cause first.
2. Do not patch symptoms if the underlying logic is broken.
3. Check indexing, state transitions, async boundaries, and lifecycle assumptions carefully.
4. Protect against boundary conditions and off-by-one errors.
5. Add or update regression tests when possible.

## Test Expectations

- Add tests for meaningful logic changes.
- Prefer focused tests over broad brittle tests.
- Cover edge cases and boundary conditions.
- Do not delete failing tests just to get green builds.
- If tests need updates because behavior intentionally changed, update them cleanly and consistently.

## Performance Expectations

- Avoid unnecessary work on the main thread.
- Avoid wasteful recomputation in SwiftUI.
- Use simple, readable optimizations where they matter.
- Do not prematurely optimize at the expense of clarity.

## Output Expectations

When asked to produce code:
- provide complete implementations
- include imports when needed
- ensure code is internally consistent
- avoid pseudocode
- avoid placeholder comments as substitutes for real work

When asked to review code:
- prioritize correctness first
- then architecture
- then UX impact
- then maintainability
- be candid about smells, risks, and weak design choices

When asked to make UI changes:
- improve the actual product feel, not just styling tokens
- favor cleaner hierarchy, fewer surfaces, better spacing, clearer emphasis
- preserve each module’s identity without turning the interface into a carnival

## Product Mindset

Always optimize for:
- trust
- clarity
- usability
- maintainability
- polish

Not for:
- novelty
- unnecessary cleverness
- over-engineering
- cosmetic churn
- fake productivity through large noisy diffs

## If Requirements Are Ambiguous

Make the most reasonable production-minded assumption based on the existing codebase and this instruction file.
Do not stall on trivial ambiguity.
If a decision could materially affect architecture, data flow, or user behavior, state the assumption clearly in your response or commit summary.

## Final Standard

Every change should leave the codebase:
- cleaner
- safer
- more coherent
- more testable
- more visually refined
- and easier to build on next
```

## File: `.github/workflows/ios-pr-verify.yml`

```yaml
name: iOS PR Verify

on:
  push:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
  workflow_dispatch:

permissions:
  contents: read
  issues: write
  pull-requests: write

jobs:
  ios-pr-verify:
    runs-on: macos-latest
    env:
      SIMULATOR_DEVICE: iPhone 15
      SIMULATOR_OS: 17.5

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build iOS app
        id: ios_build
        continue-on-error: true
        run: |
          set -o pipefail
          xcodebuild \
            -project LIFE-IN-SYNC.xcodeproj \
            -target LIFE-IN-SYNC \
            -configuration Debug \
            -sdk iphonesimulator \
            -destination "platform=iOS Simulator,name=${SIMULATOR_DEVICE},OS=${SIMULATOR_OS}" \
            clean build | tee ios-build.log

      - name: Run launch screenshot test
        id: ios_screenshots
        if: always() && steps.ios_build.outcome == 'success'
        continue-on-error: true
        run: |
          mkdir -p artifacts
          set -o pipefail
          xcodebuild \
            -project LIFE-IN-SYNC.xcodeproj \
            -scheme LIFE-IN-SYNC \
            -configuration Debug \
            -sdk iphonesimulator \
            -destination "platform=iOS Simulator,name=${SIMULATOR_DEVICE},OS=${SIMULATOR_OS}" \
            -only-testing:LIFE-IN-SYNCUITests/LIFE_IN_SYNCUITestsLaunchTests/testLaunch \
            -resultBundlePath artifacts/LIFE-IN-SYNC-LaunchTests.xcresult \
            test | tee ios-screenshot-test.log

      - name: Export screenshots
        if: always() && steps.ios_build.outcome == 'success'
        continue-on-error: true
        env:
          SIMULATOR_NAME: ${{ env.SIMULATOR_DEVICE }}
          XCRESULT_PATH: artifacts/LIFE-IN-SYNC-LaunchTests.xcresult
        run: |
          bash scripts/ci/capture_screenshots.sh

      - name: Set build result
        id: build_result
        if: always()
        run: |
          if [ "${{ steps.ios_build.outcome }}" = "success" ]; then
            echo "result=pass" >> "$GITHUB_OUTPUT"
          else
            echo "result=fail" >> "$GITHUB_OUTPUT"
          fi

      - name: Set screenshot result
        id: screenshot_result
        if: always()
        run: |
          if [ "${{ steps.ios_screenshots.outcome }}" = "success" ]; then
            echo "result=pass" >> "$GITHUB_OUTPUT"
          else
            echo "result=fail" >> "$GITHUB_OUTPUT"
          fi

      - name: Upload iOS screenshots artifact
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: ios-screenshots
          path: |
            artifacts/screenshots
          if-no-files-found: ignore

      - name: Upload iOS build logs artifact
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: ios-build-logs
          path: |
            ios-build.log
            ios-screenshot-test.log
            artifacts/LIFE-IN-SYNC-LaunchTests.xcresult
          if-no-files-found: ignore

      - name: Post sticky PR summary comment
        if: always() && github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name == github.repository
        continue-on-error: true
        uses: actions/github-script@v7
        env:
          BUILD_RESULT: ${{ steps.build_result.outputs.result }}
          SCREENSHOT_RESULT: ${{ steps.screenshot_result.outputs.result }}
          SIMULATOR_DEVICE: ${{ env.SIMULATOR_DEVICE }}
          SIMULATOR_OS: ${{ env.SIMULATOR_OS }}
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const marker = '<!-- ios-ci-summary -->';
            const result = process.env.BUILD_RESULT === 'pass' ? '✅ Pass' : '❌ Fail';
            const screenshots = process.env.SCREENSHOT_RESULT === 'pass' ? '✅ Pass' : '❌ Fail';
            const simulator = `${process.env.SIMULATOR_DEVICE} (${process.env.SIMULATOR_OS})`;
            const body = [
              marker,
              '### iOS CI Summary',
              `- Build: ${result}`,
              `- Screenshots: ${screenshots}`,
              `- Simulator: ${simulator}`,
              '- Artifacts: `ios-screenshots`, `ios-build-logs`',
              '- Phone check: open the workflow run and download `ios-screenshots` to review the latest UI snapshot.'
            ].join('\n');

            const { owner, repo } = context.repo;
            const issue_number = context.payload.pull_request.number;

            const comments = await github.paginate(github.rest.issues.listComments, {
              owner,
              repo,
              issue_number,
              per_page: 100
            });

            const existing = comments.find(
              (comment) => comment.user.type === 'Bot' && comment.body?.includes(marker)
            );

            if (existing) {
              await github.rest.issues.updateComment({
                owner,
                repo,
                comment_id: existing.id,
                body
              });
            } else {
              await github.rest.issues.createComment({
                owner,
                repo,
                issue_number,
                body
              });
            }
```

## File: `.gitignore`

```text
DerivedData/
.derived-data-log-*
*.xcuserdatad/

.DS_Store
```

## File: `ARCHITECTURE.md`

```markdown
# ARCHITECTURE

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
- analysis qualification
- swing analysis
- results review
- coaching feedback
- swing records
- issue threads
- journal/progress history

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
```

## File: `COMMIT_REVIEW_3f9d86f.md`

```markdown
# Commit Review: 3f9d86f (GarageView.swift)

## Summary
- Replaced `GarageHandPathSample` identity from `timestamp` (`Double`) to an explicit integer `id`.
- Added a static id generator and custom initializer that auto-assigns ids when not provided.

## Assessment
- Positive: avoids using floating-point values as identity keys in SwiftUI lists/charts.
- Risk: static mutable id counter can create non-deterministic IDs across runs and previews/tests.
- Risk: current static counter is not concurrency-safe if this model is created from multiple tasks.

## Follow-up Recommendations
1. Prefer deterministic ID creation from stable input (e.g., frame index + timestamp hash) instead of global mutable state.
2. If global generation is required, isolate ID generation in a dedicated actor or main-actor-only context.
3. Add a focused unit test that validates `Identifiable` stability for repeated sample generation.
```

## File: `LIFE-IN-SYNC.xcodeproj/project.pbxproj`

```text
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXContainerItemProxy section */
		9CAE3F202F7CC8A300AA0414 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 9CAE3F082F7CC8A200AA0414 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 9CAE3F0F2F7CC8A200AA0414;
			remoteInfo = "LIFE-IN-SYNC";
		};
		9CAE3F2A2F7CC8A300AA0414 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 9CAE3F082F7CC8A200AA0414 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 9CAE3F0F2F7CC8A200AA0414;
			remoteInfo = "LIFE-IN-SYNC";
		};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
		9CAE3F102F7CC8A200AA0414 /* LIFE-IN-SYNC.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "LIFE-IN-SYNC.app"; sourceTree = BUILT_PRODUCTS_DIR; };
		9CAE3F1F2F7CC8A300AA0414 /* LIFE-IN-SYNCTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = "LIFE-IN-SYNCTests.xctest"; sourceTree = BUILT_PRODUCTS_DIR; };
		9CAE3F292F7CC8A300AA0414 /* LIFE-IN-SYNCUITests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = "LIFE-IN-SYNCUITests.xctest"; sourceTree = BUILT_PRODUCTS_DIR; };
		9CAE3F5A2F7F490300AA0414 /* LIFE-IN-SYNC.xctestplan */ = {isa = PBXFileReference; lastKnownFileType = text; path = "LIFE-IN-SYNC.xctestplan"; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		9CAE3F122F7CC8A200AA0414 /* LIFE-IN-SYNC */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = "LIFE-IN-SYNC";
			sourceTree = "<group>";
		};
		9CAE3F222F7CC8A300AA0414 /* LIFE-IN-SYNCTests */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = "LIFE-IN-SYNCTests";
			sourceTree = "<group>";
		};
		9CAE3F2C2F7CC8A300AA0414 /* LIFE-IN-SYNCUITests */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = "LIFE-IN-SYNCUITests";
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		9CAE3F0D2F7CC8A200AA0414 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		9CAE3F1C2F7CC8A300AA0414 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		9CAE3F262F7CC8A300AA0414 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		9CAE3F072F7CC8A200AA0414 = {
			isa = PBXGroup;
			children = (
				9CAE3F5A2F7F490300AA0414 /* LIFE-IN-SYNC.xctestplan */,
				9CAE3F122F7CC8A200AA0414 /* LIFE-IN-SYNC */,
				9CAE3F222F7CC8A300AA0414 /* LIFE-IN-SYNCTests */,
				9CAE3F2C2F7CC8A300AA0414 /* LIFE-IN-SYNCUITests */,
				9CAE3F112F7CC8A200AA0414 /* Products */,
			);
			sourceTree = "<group>";
		};
		9CAE3F112F7CC8A200AA0414 /* Products */ = {
			isa = PBXGroup;
			children = (
				9CAE3F102F7CC8A200AA0414 /* LIFE-IN-SYNC.app */,
				9CAE3F1F2F7CC8A300AA0414 /* LIFE-IN-SYNCTests.xctest */,
				9CAE3F292F7CC8A300AA0414 /* LIFE-IN-SYNCUITests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		9CAE3F0F2F7CC8A200AA0414 /* LIFE-IN-SYNC */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 9CAE3F332F7CC8A300AA0414 /* Build configuration list for PBXNativeTarget "LIFE-IN-SYNC" */;
			buildPhases = (
				9CAE3F0C2F7CC8A200AA0414 /* Sources */,
				9CAE3F0D2F7CC8A200AA0414 /* Frameworks */,
				9CAE3F0E2F7CC8A200AA0414 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				9CAE3F122F7CC8A200AA0414 /* LIFE-IN-SYNC */,
			);
			name = "LIFE-IN-SYNC";
			packageProductDependencies = (
			);
			productName = "LIFE-IN-SYNC";
			productReference = 9CAE3F102F7CC8A200AA0414 /* LIFE-IN-SYNC.app */;
			productType = "com.apple.product-type.application";
		};
		9CAE3F1E2F7CC8A300AA0414 /* LIFE-IN-SYNCTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 9CAE3F362F7CC8A300AA0414 /* Build configuration list for PBXNativeTarget "LIFE-IN-SYNCTests" */;
			buildPhases = (
				9CAE3F1B2F7CC8A300AA0414 /* Sources */,
				9CAE3F1C2F7CC8A300AA0414 /* Frameworks */,
				9CAE3F1D2F7CC8A300AA0414 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				9CAE3F212F7CC8A300AA0414 /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				9CAE3F222F7CC8A300AA0414 /* LIFE-IN-SYNCTests */,
			);
			name = "LIFE-IN-SYNCTests";
			packageProductDependencies = (
			);
			productName = "LIFE-IN-SYNCTests";
			productReference = 9CAE3F1F2F7CC8A300AA0414 /* LIFE-IN-SYNCTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
		9CAE3F282F7CC8A300AA0414 /* LIFE-IN-SYNCUITests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 9CAE3F392F7CC8A300AA0414 /* Build configuration list for PBXNativeTarget "LIFE-IN-SYNCUITests" */;
			buildPhases = (
				9CAE3F252F7CC8A300AA0414 /* Sources */,
				9CAE3F262F7CC8A300AA0414 /* Frameworks */,
				9CAE3F272F7CC8A300AA0414 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				9CAE3F2B2F7CC8A300AA0414 /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				9CAE3F2C2F7CC8A300AA0414 /* LIFE-IN-SYNCUITests */,
			);
			name = "LIFE-IN-SYNCUITests";
			packageProductDependencies = (
			);
			productName = "LIFE-IN-SYNCUITests";
			productReference = 9CAE3F292F7CC8A300AA0414 /* LIFE-IN-SYNCUITests.xctest */;
			productType = "com.apple.product-type.bundle.ui-testing";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		9CAE3F082F7CC8A200AA0414 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2640;
				LastUpgradeCheck = 2640;
				TargetAttributes = {
					9CAE3F0F2F7CC8A200AA0414 = {
						CreatedOnToolsVersion = 26.4;
					};
					9CAE3F1E2F7CC8A300AA0414 = {
						CreatedOnToolsVersion = 26.4;
						TestTargetID = 9CAE3F0F2F7CC8A200AA0414;
					};
					9CAE3F282F7CC8A300AA0414 = {
						CreatedOnToolsVersion = 26.4;
						TestTargetID = 9CAE3F0F2F7CC8A200AA0414;
					};
				};
			};
			buildConfigurationList = 9CAE3F0B2F7CC8A200AA0414 /* Build configuration list for PBXProject "LIFE-IN-SYNC" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 9CAE3F072F7CC8A200AA0414;
			minimizedProjectReferenceProxies = 1;
			preferredProjectObjectVersion = 77;
			productRefGroup = 9CAE3F112F7CC8A200AA0414 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				9CAE3F0F2F7CC8A200AA0414 /* LIFE-IN-SYNC */,
				9CAE3F1E2F7CC8A300AA0414 /* LIFE-IN-SYNCTests */,
				9CAE3F282F7CC8A300AA0414 /* LIFE-IN-SYNCUITests */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		9CAE3F0E2F7CC8A200AA0414 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		9CAE3F1D2F7CC8A300AA0414 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		9CAE3F272F7CC8A300AA0414 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		9CAE3F0C2F7CC8A200AA0414 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		9CAE3F1B2F7CC8A300AA0414 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		9CAE3F252F7CC8A300AA0414 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		9CAE3F212F7CC8A300AA0414 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = 9CAE3F0F2F7CC8A200AA0414 /* LIFE-IN-SYNC */;
			targetProxy = 9CAE3F202F7CC8A300AA0414 /* PBXContainerItemProxy */;
		};
		9CAE3F2B2F7CC8A300AA0414 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = 9CAE3F0F2F7CC8A200AA0414 /* LIFE-IN-SYNC */;
			targetProxy = 9CAE3F2A2F7CC8A300AA0414 /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		9CAE3F312F7CC8A300AA0414 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		9CAE3F322F7CC8A300AA0414 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SWIFT_COMPILATION_MODE = wholemodule;
			};
			name = Release;
		};
		9CAE3F342F7CC8A300AA0414 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 9WCDSNG464;
				ENABLE_APP_SANDBOX = YES;
				ENABLE_PREVIEWS = YES;
				ENABLE_USER_SELECTED_FILES = readonly;
				GENERATE_INFOPLIST_FILE = YES;
				"INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=iphoneos*]" = YES;
				"INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=iphonesimulator*]" = YES;
				"INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents[sdk=iphoneos*]" = YES;
				"INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents[sdk=iphonesimulator*]" = YES;
				"INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphoneos*]" = YES;
				"INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphonesimulator*]" = YES;
				"INFOPLIST_KEY_UIStatusBarStyle[sdk=iphoneos*]" = UIStatusBarStyleDefault;
				"INFOPLIST_KEY_UIStatusBarStyle[sdk=iphonesimulator*]" = UIStatusBarStyleDefault;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 26.4;
				LD_RUNPATH_SEARCH_PATHS = "@executable_path/Frameworks";
				"LD_RUNPATH_SEARCH_PATHS[sdk=macosx*]" = "@executable_path/../Frameworks";
				MACOSX_DEPLOYMENT_TARGET = 26.4;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "LIS.LIFE-IN-SYNC";
				PRODUCT_NAME = "$(TARGET_NAME)";
				REGISTER_APP_GROUPS = YES;
				SDKROOT = auto;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator";
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2,7";
				XROS_DEPLOYMENT_TARGET = 26.4;
			};
			name = Debug;
		};
		9CAE3F352F7CC8A300AA0414 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 9WCDSNG464;
				ENABLE_APP_SANDBOX = YES;
				ENABLE_PREVIEWS = YES;
				ENABLE_USER_SELECTED_FILES = readonly;
				GENERATE_INFOPLIST_FILE = YES;
				"INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=iphoneos*]" = YES;
				"INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=iphonesimulator*]" = YES;
				"INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents[sdk=iphoneos*]" = YES;
				"INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents[sdk=iphonesimulator*]" = YES;
				"INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphoneos*]" = YES;
				"INFOPLIST_KEY_UILaunchScreen_Generation[sdk=iphonesimulator*]" = YES;
				"INFOPLIST_KEY_UIStatusBarStyle[sdk=iphoneos*]" = UIStatusBarStyleDefault;
				"INFOPLIST_KEY_UIStatusBarStyle[sdk=iphonesimulator*]" = UIStatusBarStyleDefault;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 26.4;
				LD_RUNPATH_SEARCH_PATHS = "@executable_path/Frameworks";
				"LD_RUNPATH_SEARCH_PATHS[sdk=macosx*]" = "@executable_path/../Frameworks";
				MACOSX_DEPLOYMENT_TARGET = 26.4;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "LIS.LIFE-IN-SYNC";
				PRODUCT_NAME = "$(TARGET_NAME)";
				REGISTER_APP_GROUPS = YES;
				SDKROOT = auto;
				STRING_CATALOG_GENERATE_SYMBOLS = YES;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator";
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2,7";
				XROS_DEPLOYMENT_TARGET = 26.4;
			};
			name = Release;
		};
		9CAE3F372F7CC8A300AA0414 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 9WCDSNG464;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 26.4;
				MACOSX_DEPLOYMENT_TARGET = 26.4;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "LIS.LIFE-IN-SYNCTests";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = auto;
				STRING_CATALOG_GENERATE_SYMBOLS = NO;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator";
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2,7";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/LIFE-IN-SYNC.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/LIFE-IN-SYNC";
				XROS_DEPLOYMENT_TARGET = 26.4;
			};
			name = Debug;
		};
		9CAE3F382F7CC8A300AA0414 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 9WCDSNG464;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 26.4;
				MACOSX_DEPLOYMENT_TARGET = 26.4;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "LIS.LIFE-IN-SYNCTests";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = auto;
				STRING_CATALOG_GENERATE_SYMBOLS = NO;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator";
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2,7";
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/LIFE-IN-SYNC.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/LIFE-IN-SYNC";
				XROS_DEPLOYMENT_TARGET = 26.4;
			};
			name = Release;
		};
		9CAE3F3A2F7CC8A300AA0414 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 9WCDSNG464;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 26.4;
				MACOSX_DEPLOYMENT_TARGET = 26.4;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "LIS.LIFE-IN-SYNCUITests";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = auto;
				STRING_CATALOG_GENERATE_SYMBOLS = NO;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator";
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2,7";
				TEST_TARGET_NAME = "LIFE-IN-SYNC";
				XROS_DEPLOYMENT_TARGET = 26.4;
			};
			name = Debug;
		};
		9CAE3F3B2F7CC8A300AA0414 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 9WCDSNG464;
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 26.4;
				MACOSX_DEPLOYMENT_TARGET = 26.4;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "LIS.LIFE-IN-SYNCUITests";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = auto;
				STRING_CATALOG_GENERATE_SYMBOLS = NO;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator";
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2,7";
				TEST_TARGET_NAME = "LIFE-IN-SYNC";
				XROS_DEPLOYMENT_TARGET = 26.4;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		9CAE3F0B2F7CC8A200AA0414 /* Build configuration list for PBXProject "LIFE-IN-SYNC" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				9CAE3F312F7CC8A300AA0414 /* Debug */,
				9CAE3F322F7CC8A300AA0414 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		9CAE3F332F7CC8A300AA0414 /* Build configuration list for PBXNativeTarget "LIFE-IN-SYNC" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				9CAE3F342F7CC8A300AA0414 /* Debug */,
				9CAE3F352F7CC8A300AA0414 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		9CAE3F362F7CC8A300AA0414 /* Build configuration list for PBXNativeTarget "LIFE-IN-SYNCTests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				9CAE3F372F7CC8A300AA0414 /* Debug */,
				9CAE3F382F7CC8A300AA0414 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		9CAE3F392F7CC8A300AA0414 /* Build configuration list for PBXNativeTarget "LIFE-IN-SYNCUITests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				9CAE3F3A2F7CC8A300AA0414 /* Debug */,
				9CAE3F3B2F7CC8A300AA0414 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = 9CAE3F082F7CC8A200AA0414 /* Project object */;
}
```

## File: `LIFE-IN-SYNC.xcodeproj/project.xcworkspace/contents.xcworkspacedata`

```text
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
```

## File: `LIFE-IN-SYNC.xcodeproj/xcshareddata/xcschemes/LIFE-IN-SYNC.xcscheme`

```text
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2640"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      buildArchitectures = "Automatic">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "9CAE3F0F2F7CC8A200AA0414"
               BuildableName = "LIFE-IN-SYNC.app"
               BlueprintName = "LIFE-IN-SYNC"
               ReferencedContainer = "container:LIFE-IN-SYNC.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <TestPlans>
         <TestPlanReference
            reference = "container:LIFE-IN-SYNC.xctestplan"
            default = "YES">
         </TestPlanReference>
      </TestPlans>
      <Testables>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "9CAE3F1E2F7CC8A300AA0414"
               BuildableName = "LIFE-IN-SYNCTests.xctest"
               BlueprintName = "LIFE-IN-SYNCTests"
               ReferencedContainer = "container:LIFE-IN-SYNC.xcodeproj">
            </BuildableReference>
         </TestableReference>
         <TestableReference
            skipped = "NO"
            parallelizable = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "9CAE3F282F7CC8A300AA0414"
               BuildableName = "LIFE-IN-SYNCUITests.xctest"
               BlueprintName = "LIFE-IN-SYNCUITests"
               ReferencedContainer = "container:LIFE-IN-SYNC.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES"
      queueDebuggingEnableBacktraceRecording = "Yes">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "9CAE3F0F2F7CC8A200AA0414"
            BuildableName = "LIFE-IN-SYNC.app"
            BlueprintName = "LIFE-IN-SYNC"
            ReferencedContainer = "container:LIFE-IN-SYNC.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "9CAE3F0F2F7CC8A200AA0414"
            BuildableName = "LIFE-IN-SYNC.app"
            BlueprintName = "LIFE-IN-SYNC"
            ReferencedContainer = "container:LIFE-IN-SYNC.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
```

## File: `LIFE-IN-SYNC.xcodeproj/xcuserdata/colton.xcuserdatad/xcschemes/xcschememanagement.plist`

```text
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>SchemeUserState</key>
	<dict>
		<key>LIFE-IN-SYNC.xcscheme_^#shared#^_</key>
		<dict>
			<key>orderHint</key>
			<integer>0</integer>
		</dict>
	</dict>
</dict>
</plist>
```

## File: `LIFE-IN-SYNC.xctestplan`

```json
{
  "configurations" : [
    {
      "id" : "2C5B7D63-12E6-4E81-B3B7-9C7B0D6D0A11",
      "name" : "Default",
      "options" : {
        "codeCoverage" : false
      }
    }
  ],
  "defaultOptions" : {
    "codeCoverage" : false,
    "targetForVariableExpansion" : {
      "containerPath" : "container:LIFE-IN-SYNC.xcodeproj",
      "identifier" : "9CAE3F0F2F7CC8A200AA0414",
      "name" : "LIFE-IN-SYNC"
    }
  },
  "testTargets" : [
    {
      "parallelizable" : false,
      "target" : {
        "containerPath" : "container:LIFE-IN-SYNC.xcodeproj",
        "identifier" : "9CAE3F1E2F7CC8A300AA0414",
        "name" : "LIFE-IN-SYNCTests"
      }
    },
    {
      "target" : {
        "containerPath" : "container:LIFE-IN-SYNC.xcodeproj",
        "identifier" : "9CAE3F282F7CC8A300AA0414",
        "name" : "LIFE-IN-SYNCUITests"
      }
    }
  ],
  "version" : 1
}
```

## File: `LIFE-IN-SYNC/AddSwingRecordSheet.swift`

```swift
import SwiftUI
import PhotosUI
import AVFoundation
import SwiftData

struct AddSwingRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let autoPresentPicker: Bool
    let autoImportOnSelection: Bool
    let onSaved: (SwingRecord) -> Void

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var selectedVideoURL: URL?
    @State private var selectedVideoFilename = ""
    @State private var isShowingVideoPicker = false
    @State private var isPreparingSelection = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ModuleSpacing.large) {
                    ModuleRowSurface(theme: AppModule.garage.theme) {
                        if let selectedVideoURL {
                            GarageSelectedVideoPreview(
                                videoURL: selectedVideoURL,
                                filename: selectedVideoFilename,
                                replaceVideo: { isShowingVideoPicker = true },
                                removeVideo: removeSelectedVideo
                            )
                        } else {
                            VStack(alignment: .leading, spacing: ModuleSpacing.small) {
                                Text("Select a swing video")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                                Text("Start by choosing one clip. Garage will save it locally, then take you straight into review.")
                                    .foregroundStyle(AppModule.garage.theme.textSecondary)
                                Button("Choose Video") {
                                    isShowingVideoPicker = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppModule.garage.theme.primary)
                            }
                        }
                    }

                    if autoImportOnSelection == false {
                        ModuleRowSurface(theme: AppModule.garage.theme) {
                            Text("Save Details")
                                .font(.headline)
                                .foregroundStyle(AppModule.garage.theme.textPrimary)

                            TextField("Title (optional)", text: $title)
                            TextField("Notes (optional)", text: $notes, axis: .vertical)
                                .lineLimit(4, reservesSpace: true)
                        }
                    }
                }
                .padding(.horizontal, ModuleSpacing.large)
                .padding(.vertical, ModuleSpacing.medium)
            }
            .navigationTitle(autoImportOnSelection ? "Import Swing Video" : "New Swing Record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if autoImportOnSelection == false {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isSaving ? "Saving..." : "Save") {
                            saveRecord()
                        }
                        .disabled(selectedVideoURL == nil || isPreparingSelection || isSaving)
                    }
                }
            }
            .photosPicker(
                isPresented: $isShowingVideoPicker,
                selection: $selectedVideoItem,
                matching: .videos,
                preferredItemEncoding: .current
            )
            .onChange(of: selectedVideoItem) { _, newItem in
                guard let newItem else { return }
                prepareSelectedVideo(newItem)
            }
            .task {
                guard autoPresentPicker, selectedVideoURL == nil, isShowingVideoPicker == false else { return }
                isShowingVideoPicker = true
            }
            .overlay {
                if isPreparingSelection || isSaving {
                    GarageAddRecordProgressOverlay(isSaving: isSaving)
                }
            }
            .alert(
                "Garage Video Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in
                        if isPresented == false {
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @MainActor
    private func prepareSelectedVideo(_ item: PhotosPickerItem) {
        isPreparingSelection = true
        errorMessage = nil

        Task {
            do {
                guard let movie = try await item.loadTransferable(type: GaragePickedMovie.self) else {
                    throw GarageImportError.unableToLoadSelection
                }

                await MainActor.run {
                    selectedVideoURL = movie.url
                    selectedVideoFilename = movie.displayName
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        title = suggestedTitle(for: movie.displayName)
                    }
                    isPreparingSelection = false
                    if autoImportOnSelection {
                        saveRecord()
                    }
                }
            } catch {
                await MainActor.run {
                    selectedVideoItem = nil
                    selectedVideoURL = nil
                    selectedVideoFilename = ""
                    isPreparingSelection = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func removeSelectedVideo() {
        selectedVideoItem = nil
        selectedVideoURL = nil
        selectedVideoFilename = ""
    }

    private func saveRecord() {
        guard let selectedVideoURL else { return }
        guard isSaving == false else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let reviewMasterURL = try GarageMediaStore.persistReviewMaster(from: selectedVideoURL)
                async let analysisTask = GarageAnalysisPipeline.analyzeVideo(at: reviewMasterURL)
                async let exportTask = GarageMediaStore.createExportDerivative(from: reviewMasterURL)

                let output = try await analysisTask
                let exportURL = await exportTask
                let resolvedTitle = resolvedRecordTitle(fallbackURL: reviewMasterURL)
                let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                let reviewMasterBookmark = GarageMediaStore.bookmarkData(for: reviewMasterURL)
                let exportBookmark = exportURL.flatMap { GarageMediaStore.bookmarkData(for: $0) }

                let record = SwingRecord(
                    title: resolvedTitle,
                    mediaFilename: reviewMasterURL.lastPathComponent,
                    mediaFileBookmark: reviewMasterBookmark,
                    reviewMasterFilename: reviewMasterURL.lastPathComponent,
                    reviewMasterBookmark: reviewMasterBookmark,
                    exportAssetFilename: exportURL?.lastPathComponent,
                    exportAssetBookmark: exportBookmark,
                    notes: trimmedNotes,
                    frameRate: output.frameRate,
                    swingFrames: output.swingFrames,
                    keyFrames: output.keyFrames,
                    handAnchors: output.handAnchors,
                    pathPoints: output.pathPoints,
                    analysisResult: output.analysisResult
                )

                await MainActor.run {
                    modelContext.insert(record)
                    try? modelContext.save()
                    isSaving = false
                    onSaved(record)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func resolvedRecordTitle(fallbackURL: URL) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty == false {
            return trimmedTitle
        }

        let preferredName = selectedVideoFilename.isEmpty ? fallbackURL.lastPathComponent : selectedVideoFilename
        return suggestedTitle(for: preferredName)
    }

    private func suggestedTitle(for filename: String) -> String {
        let stem = URL(filePath: filename).deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if stem.isEmpty == false {
            return stem
        }

        return "Swing \(Date.now.formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct GarageSelectedVideoPreview: View {
    let videoURL: URL
    let filename: String
    let replaceVideo: () -> Void
    let removeVideo: () -> Void

    @State private var previewImage: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .fill(AppModule.garage.theme.surfaceSecondary)

                if let previewImage {
                    Image(decorative: previewImage, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppModule.garage.theme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                    .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
            )

            Text(filename)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)
                .lineLimit(1)

            HStack(spacing: ModuleSpacing.small) {
                Button("Choose Different Video", action: replaceVideo)
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.garage.theme.primary)
                Button("Remove", role: .destructive, action: removeVideo)
                    .buttonStyle(.bordered)
            }
        }
        .task(id: videoURL) {
            previewImage = await GarageMediaStore.thumbnail(for: videoURL, at: 0)
        }
    }
}

private struct GarageAddRecordProgressOverlay: View {
    let isSaving: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            ModuleRowSurface(theme: AppModule.garage.theme) {
                HStack(alignment: .center, spacing: ModuleSpacing.medium) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppModule.garage.theme.primary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isSaving ? "Importing swing" : "Loading preview")
                            .font(.headline)
                            .foregroundStyle(AppModule.garage.theme.textPrimary)
                        Text("Please hold for a moment.")
                            .foregroundStyle(AppModule.garage.theme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, ModuleSpacing.large)
        }
    }
}

private struct GaragePickedMovie: Transferable {
    let url: URL
    let displayName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let originalFilename = received.file.lastPathComponent.isEmpty ? "swing.mov" : received.file.lastPathComponent
            let stem = URL(fileURLWithPath: originalFilename).deletingPathExtension().lastPathComponent
            let ext = URL(fileURLWithPath: originalFilename).pathExtension.isEmpty ? "mov" : URL(fileURLWithPath: originalFilename).pathExtension
            let sanitizedStem = stem.replacingOccurrences(of: "/", with: "-")
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(sanitizedStem)-\(UUID().uuidString.prefix(8))")
                .appendingPathExtension(ext)

            if FileManager.default.fileExists(atPath: destinationURL.path()) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: received.file, to: destinationURL)
            return GaragePickedMovie(url: destinationURL, displayName: originalFilename)
        }
    }
}

private enum GarageImportError: LocalizedError {
    case unableToLoadSelection

    var errorDescription: String? {
        switch self {
        case .unableToLoadSelection:
            "The selected video could not be loaded from Photos."
        }
    }
}
```

## File: `LIFE-IN-SYNC/AppModule.swift`

```swift
import SwiftUI

enum AppModule: String, CaseIterable, Identifiable {
    case dashboard
    case capitalCore
    case ironTemple
    case garage
    case habitStack
    case taskProtocol
    case calendar
    case bibleStudy
    case supplyList

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            "Dashboard"
        case .capitalCore:
            "Capital Core"
        case .ironTemple:
            "Iron Temple"
        case .garage:
            "Garage"
        case .habitStack:
            "Habit Stack"
        case .taskProtocol:
            "Task Protocol"
        case .calendar:
            "Calendar"
        case .bibleStudy:
            "Bible Study"
        case .supplyList:
            "Supply List"
        }
    }

    var navigationTitle: String {
        switch self {
        case .dashboard:
            "Life In Sync"
        default:
            title
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            "house"
        case .capitalCore:
            "dollarsign.circle"
        case .ironTemple:
            "dumbbell"
        case .garage:
            "figure.golf"
        case .habitStack:
            "checklist"
        case .taskProtocol:
            "checkmark.circle"
        case .calendar:
            "calendar"
        case .bibleStudy:
            "book.closed"
        case .supplyList:
            "cart"
        }
    }

    var summary: String {
        switch self {
        case .dashboard:
            "Today overview and fast routing."
        case .capitalCore:
            "Track expenses, budgets, and current financial position."
        case .ironTemple:
            "Plan workouts and log sessions."
        case .garage:
            "Review swing records and coaching notes."
        case .habitStack:
            "Manage recurring habits and streaks."
        case .taskProtocol:
            "Capture and complete one-time tasks."
        case .calendar:
            "Plan your day and upcoming events."
        case .bibleStudy:
            "Save passages, notes, and study history."
        case .supplyList:
            "Build shopping lists and track purchased items."
        }
    }

    var theme: ModuleTheme {
        switch self {
        case .dashboard:
            ModuleTheme(
                primary: .blue,
                secondary: .cyan,
                backgroundTop: .blue.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .blue
            )
        case .capitalCore:
            ModuleTheme(
                primary: .green,
                secondary: .mint,
                backgroundTop: .green.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .green
            )
        case .ironTemple:
            ModuleTheme(
                primary: .orange,
                secondary: .yellow,
                backgroundTop: .orange.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .orange
            )
        case .garage:
            ModuleTheme(
                primary: .mint,
                secondary: .teal,
                backgroundTop: .mint.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .mint
            )
        case .habitStack:
            ModuleTheme(
                primary: .indigo,
                secondary: .purple,
                backgroundTop: .indigo.opacity(0.2),
                backgroundBottom: .clear,
                accentText: .indigo
            )
        case .taskProtocol:
            ModuleTheme(
                primary: .teal,
                secondary: .cyan,
                backgroundTop: .teal.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .teal
            )
        case .calendar:
            ModuleTheme(
                primary: .red,
                secondary: .pink,
                backgroundTop: .red.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .red
            )
        case .bibleStudy:
            ModuleTheme(
                primary: .brown,
                secondary: .orange,
                backgroundTop: .brown.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .brown
            )
        case .supplyList:
            ModuleTheme(
                primary: .pink,
                secondary: .red,
                backgroundTop: .pink.opacity(0.18),
                backgroundBottom: .clear,
                accentText: .pink
            )
        }
    }

    var tintColor: Color { theme.primary }
}
```

## File: `LIFE-IN-SYNC/AppShellView.swift`

```swift
import SwiftData
import SwiftUI

struct AppShellView: View {
    @State private var selectedModule: AppModule = .dashboard
    @State private var isShowingModuleMenu = false

    init(initialModule: AppModule = .dashboard) {
        _selectedModule = State(initialValue: initialModule)
    }

    var body: some View {
        NavigationStack {
            currentModuleView
                .navigationTitle(selectedModule.navigationTitle)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isShowingModuleMenu = true
                        } label: {
                            Label("Modules", systemImage: "square.grid.2x2")
                        }
                        .accessibilityIdentifier("open-module-menu")
                    }

                    ToolbarItem(placement: .automatic) {
                        if selectedModule != .dashboard {
                            Button("Dashboard") {
                                selectedModule = .dashboard
                            }
                            .accessibilityIdentifier("return-to-dashboard")
                        }
                    }
                }
                .tint(selectedModule.tintColor)
                .background(selectedModule.theme.screenGradient)
        }
        .sheet(isPresented: $isShowingModuleMenu) {
            NavigationStack {
                ModuleMenuView(selectedModule: $selectedModule)
                    .tint(selectedModule.tintColor)
            }
        }
    }

    @ViewBuilder
    private var currentModuleView: some View {
        switch selectedModule {
        case .dashboard:
            DashboardView(selectedModule: $selectedModule)
        case .capitalCore:
            CapitalCoreView()
        case .ironTemple:
            IronTempleView()
        case .garage:
            GarageView()
        case .habitStack:
            HabitStackView()
        case .taskProtocol:
            TaskProtocolView()
        case .calendar:
            CalendarView()
        case .bibleStudy:
            BibleStudyView()
        case .supplyList:
            SupplyListView()
        }
    }
}

#Preview("Shell Dashboard") {
    AppShellView()
        .modelContainer(PreviewCatalog.populatedApp)
}

#Preview("Shell Calendar") {
    AppShellView(initialModule: .calendar)
        .modelContainer(PreviewCatalog.populatedApp)
}
```

## File: `LIFE-IN-SYNC/Assets.xcassets/AccentColor.colorset/Contents.json`

```json
{
  "colors" : [
    {
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

## File: `LIFE-IN-SYNC/Assets.xcassets/AppIcon.appiconset/Contents.json`

```json
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

## File: `LIFE-IN-SYNC/Assets.xcassets/Contents.json`

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

## File: `LIFE-IN-SYNC/BibleStudyView.swift`

```swift
import SwiftData
import SwiftUI

struct BibleStudyView: View {
    @Query(sort: \StudyEntry.createdAt, order: .reverse) private var entries: [StudyEntry]
    @State private var isShowingAddEntry = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModuleHeroCard(
                    module: .bibleStudy,
                    eyebrow: "Live Module",
                    title: "Keep study sessions simple and grounded.",
                    message: "Bible Study starts with passage references, entry titles, and local notes so you can build a clear history over time."
                )

                BibleStudyOverviewCard(entryCount: entries.count)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Study Entries")
                        .font(.headline)

                    if entries.isEmpty {
                        BibleStudyEmptyStateView {
                            isShowingAddEntry = true
                        }
                    } else {
                        ForEach(entries.prefix(8)) { entry in
                            StudyEntryCard(entry: entry)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppModule.bibleStudy.theme.screenGradient)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    isShowingAddEntry = true
                } label: {
                    Label("Add Study Entry", systemImage: "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppModule.bibleStudy.theme.primary)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $isShowingAddEntry) {
            AddStudyEntrySheet()
        }
    }
}

private struct BibleStudyOverviewCard: View {
    let entryCount: Int

    var body: some View {
        ModuleSnapshotCard(title: "Study Snapshot") {
            HStack(spacing: 12) {
                ModuleMetricChip(theme: AppModule.bibleStudy.theme, title: "Entries", value: "\(entryCount)")
                ModuleMetricChip(theme: AppModule.bibleStudy.theme, title: "Focus", value: "Scripture")
            }
        }
    }
}

private struct StudyEntryCard: View {
    let entry: StudyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.headline)

            Text(entry.passageReference)
                .font(.subheadline)
                .foregroundStyle(AppModule.bibleStudy.theme.primary)

            if entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Text(entry.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct BibleStudyEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.bibleStudy.theme,
            title: "No study entries yet",
            message: "Capture a passage reference, title, and short reflection to start building your study history.",
            actionTitle: "Add First Entry",
            action: action
        )
    }
}

private struct AddStudyEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var passageReference = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Study Entry") {
                    TextField("Title", text: $title)
                    TextField("Passage Reference", text: $passageReference)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle("New Study Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedPassage = passageReference.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedTitle.isEmpty == false, trimmedPassage.isEmpty == false else {
                            return
                        }

                        modelContext.insert(
                            StudyEntry(
                                title: trimmedTitle,
                                passageReference: trimmedPassage,
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(
                        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        passageReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}

#Preview("Bible Study") {
    PreviewScreenContainer {
        BibleStudyView()
    }
    .modelContainer(for: StudyEntry.self, inMemory: true)
}
```

## File: `LIFE-IN-SYNC/CalendarView.swift`

```swift
import SwiftData
import SwiftUI

struct CalendarView: View {
    @Query(sort: \CalendarEvent.startDate) private var events: [CalendarEvent]
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var isShowingAddEvent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModuleHeroCard(
                    module: .calendar,
                    eyebrow: "Live Module",
                    title: "Keep the day visible.",
                    message: "Calendar owns time-based planning. It stays simple here: choose a day, create events, and review tasks with due dates."
                )

                CalendarDateCard(selectedDate: $selectedDate)

                VStack(alignment: .leading, spacing: 12) {
                    Text(daySectionTitle)
                        .font(.headline)

                    if eventsForSelectedDate.isEmpty {
                        CalendarEmptyStateView(
                            title: "No events on this day",
                            message: "Add a time block or appointment to start shaping the agenda.",
                            actionTitle: "Add Event",
                            action: { isShowingAddEvent = true }
                        )
                    } else {
                        ForEach(eventsForSelectedDate) { event in
                            CalendarEventCard(event: event)
                        }
                    }
                }

                if dueTasksForSelectedDate.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tasks Due")
                            .font(.headline)

                        ForEach(dueTasksForSelectedDate) { task in
                            CalendarTaskCard(task: task)
                        }
                    }
                }

                if upcomingEvents.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming")
                            .font(.headline)

                        ForEach(upcomingEvents.prefix(5)) { event in
                            CalendarEventCard(event: event)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppModule.calendar.theme.screenGradient)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    isShowingAddEvent = true
                } label: {
                    Label("Add Event", systemImage: "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppModule.calendar.theme.primary)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $isShowingAddEvent) {
            AddEventSheet(defaultDate: selectedDate)
        }
    }

    private var daySectionTitle: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today's Agenda"
        }

        return selectedDate.formatted(date: .complete, time: .omitted)
    }

    private var eventsForSelectedDate: [CalendarEvent] {
        let calendar = Calendar.current
        return events.filter { calendar.isDate($0.startDate, inSameDayAs: selectedDate) }
    }

    private var dueTasksForSelectedDate: [TaskItem] {
        let calendar = Calendar.current
        return tasks.filter { task in
            guard let dueDate = task.dueDate else {
                return false
            }

            return calendar.isDate(dueDate, inSameDayAs: selectedDate) && task.isCompleted == false
        }
    }

    private var upcomingEvents: [CalendarEvent] {
        events.filter { $0.startDate >= .now && Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) == false }
    }
}

private struct CalendarDateCard: View {
    @Binding var selectedDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Selected Day")
                .font(.headline)
            DatePicker(
                "Day",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct CalendarEventCard: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Text(event.startDate.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .fontWeight(.semibold)
                Rectangle()
                    .fill(AppModule.calendar.theme.primary.opacity(0.4))
                    .frame(width: 2, height: 36)
            }
            .frame(width: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.headline)
                Text(timeRangeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var timeRangeText: String {
        "\(event.startDate.formatted(.dateTime.hour().minute())) - \(event.endDate.formatted(.dateTime.hour().minute()))"
    }
}

private struct CalendarTaskCard: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(AppModule.taskProtocol.theme.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                if let dueDate = task.dueDate {
                    Text(dueDate.formatted(date: .omitted, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct CalendarEmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(AppModule.calendar.theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var startDate: Date
    @State private var endDate: Date

    init(defaultDate: Date) {
        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: defaultDate) ?? defaultDate
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Event title", text: $title)
                    DatePicker("Start", selection: $startDate)
                    DatePicker("End", selection: $endDate, in: startDate...)
                }
            }
            .navigationTitle("New Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedTitle.isEmpty == false else {
                            return
                        }

                        modelContext.insert(
                            CalendarEvent(
                                title: trimmedTitle,
                                startDate: startDate,
                                endDate: endDate
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview("Calendar") {
    PreviewScreenContainer {
        CalendarView()
    }
    .modelContainer(for: [CalendarEvent.self, TaskItem.self], inMemory: true)
}
```

## File: `LIFE-IN-SYNC/CapitalCoreView.swift`

```swift
import SwiftData
import SwiftUI

struct CapitalCoreView: View {
    @Query(sort: \ExpenseRecord.recordedAt, order: .reverse) private var expenses: [ExpenseRecord]
    @Query(sort: \BudgetRecord.title) private var budgets: [BudgetRecord]
    @State private var isShowingAddExpense = false
    @State private var isShowingAddBudget = false
    @State private var selectedTab: ModuleHubTab = .overview

    var body: some View {
        ModuleHubScaffold(
            module: .capitalCore,
            title: "Track money without extra noise.",
            subtitle: "Simple local capture for expenses and budgets with clear monthly visibility.",
            currentState: "\(currentMonthExpenses.count) expense entries logged this month.",
            nextAttention: budgets.isEmpty ? "Create your first budget target." : "Review categories running above target.",
            tabs: [.overview, .entries, .advisor],
            selectedTab: $selectedTab
        ) {
            switch selectedTab {
            case .overview:
                CapitalOverviewTab(
                    monthlySpend: currentMonthExpenses.reduce(0) { $0 + $1.amount },
                    expenseCount: currentMonthExpenses.count,
                    budgets: budgets,
                    spentAmount: spentAmount(for:)
                ) {
                    isShowingAddBudget = true
                }
            case .entries:
                CapitalEntriesTab(expenses: expenses) {
                    isShowingAddExpense = true
                }
            case .advisor:
                ModuleEmptyStateCard(
                    theme: AppModule.capitalCore.theme,
                    title: "Advisor remains user-triggered",
                    message: "Use this tab for guided prompts only. No autonomous writes happen without explicit confirmation.",
                    actionTitle: "Add Expense",
                    action: { isShowingAddExpense = true }
                )
            default:
                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    isShowingAddExpense = true
                } label: {
                    Label("Add Expense", systemImage: "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppModule.capitalCore.theme.primary)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $isShowingAddExpense) {
            AddExpenseSheet()
        }
        .sheet(isPresented: $isShowingAddBudget) {
            AddBudgetSheet()
        }
    }

    private var currentMonthExpenses: [ExpenseRecord] {
        expenses.filter { Calendar.current.isDate($0.recordedAt, equalTo: .now, toGranularity: .month) }
    }

    private func spentAmount(for budget: BudgetRecord) -> Double {
        currentMonthExpenses
            .filter { $0.category == budget.title }
            .reduce(0) { $0 + $1.amount }
    }
}

private struct CapitalOverviewTab: View {
    let monthlySpend: Double
    let expenseCount: Int
    let budgets: [BudgetRecord]
    let spentAmount: (BudgetRecord) -> Double
    let createBudget: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            CapitalOverviewCard(
                monthlySpend: monthlySpend,
                expenseCount: expenseCount,
                budgetCount: budgets.count
            )

            ModuleActivityFeedSection(title: "Current Budgets") {
                HStack {
                    Spacer()
                    Button("Add Budget", action: createBudget)
                        .buttonStyle(.bordered)
                }

                if budgets.isEmpty {
                    CapitalEmptyStateView(
                        title: "No budgets yet",
                        message: "Set a simple target to keep spending visible.",
                        actionTitle: "Create Budget",
                        action: createBudget
                    )
                } else {
                    ForEach(budgets) { budget in
                        BudgetCard(budget: budget, spentAmount: spentAmount(budget))
                    }
                }
            }
        }
    }
}

private struct CapitalEntriesTab: View {
    let expenses: [ExpenseRecord]
    let addExpense: () -> Void

    var body: some View {
        ModuleActivityFeedSection(title: "Recent Expenses") {
            if expenses.isEmpty {
                CapitalEmptyStateView(
                    title: "No expenses logged",
                    message: "Add the first expense to start building your monthly picture.",
                    actionTitle: "Add Expense",
                    action: addExpense
                )
            } else {
                ForEach(expenses.prefix(8)) { expense in
                    ExpenseCard(expense: expense)
                }
            }
        }
    }
}

private struct CapitalOverviewCard: View {
    let monthlySpend: Double
    let expenseCount: Int
    let budgetCount: Int

    var body: some View {
        ModuleVisualizationContainer(title: "Month Snapshot") {
            HStack(spacing: 12) {
                CapitalMetricChip(title: "Spent", value: monthlySpend, currency: true)
                CapitalMetricChip(title: "Expenses", value: Double(expenseCount), currency: false)
                CapitalMetricChip(title: "Budgets", value: Double(budgetCount), currency: false)
            }
        }
    }
}

private struct CapitalMetricChip: View {
    let title: String
    let value: Double
    let currency: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(formattedValue)
                .font(ModuleTypography.metricValue)
            Text(title)
                .font(ModuleTypography.supportingLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(AppModule.capitalCore.theme.chipBackground, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous))
    }

    private var formattedValue: String {
        if currency {
            value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        } else {
            Int(value).formatted()
        }
    }
}

private struct BudgetCard: View {
    let budget: BudgetRecord
    let spentAmount: Double

    private var progress: Double {
        guard budget.limitAmount > 0 else { return 0 }
        return min(spentAmount / budget.limitAmount, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.title)
                        .font(.headline)
                    Text(budget.periodLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(spentAmount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))) / \(budget.limitAmount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(AppModule.capitalCore.theme.primary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
    }
}

private struct ExpenseCard: View {
    let expense: ExpenseRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.headline)
                Text(expense.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(expense.amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                    .font(.headline)
                Text(expense.recordedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct CapitalEmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.capitalCore.theme,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
    }
}

private struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var amount = ""
    @State private var category = "General"

    private let categories = ["General", "Food", "Transport", "Bills", "Health", "Shopping"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    TextField("Expense title", text: $title)
                    TextField("Amount", text: $amount)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("New Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedTitle.isEmpty == false, let amountValue = Double(amount) else {
                            return
                        }

                        modelContext.insert(
                            ExpenseRecord(
                                title: trimmedTitle,
                                amount: amountValue,
                                category: category
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Double(amount) == nil)
                }
            }
        }
    }
}

private struct AddBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = "General"
    @State private var limitAmount = ""
    @State private var periodLabel = "Monthly"

    private let categories = ["General", "Food", "Transport", "Bills", "Health", "Shopping"]
    private let periods = ["Weekly", "Monthly"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget Details") {
                    Picker("Category", selection: $title) {
                        ForEach(categories, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }

                    TextField("Limit Amount", text: $limitAmount)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif

                    Picker("Period", selection: $periodLabel) {
                        ForEach(periods, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("New Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let limitValue = Double(limitAmount) else {
                            return
                        }

                        modelContext.insert(
                            BudgetRecord(
                                title: title,
                                limitAmount: limitValue,
                                periodLabel: periodLabel
                            )
                        )
                        dismiss()
                    }
                    .disabled(Double(limitAmount) == nil)
                }
            }
        }
    }
}

#Preview("Capital Core") {
    PreviewScreenContainer {
        CapitalCoreView()
    }
    .modelContainer(for: [ExpenseRecord.self, BudgetRecord.self], inMemory: true)
}
```

## File: `LIFE-IN-SYNC/ContentView.swift`

```swift
import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var isShowingLaunchAffirmation = !LaunchAffirmationConfiguration.shouldSkip

    init(showLaunchAffirmation: Bool = !LaunchAffirmationConfiguration.shouldSkip) {
        _isShowingLaunchAffirmation = State(initialValue: showLaunchAffirmation)
    }

    var body: some View {
        ZStack {
            if isShowingLaunchAffirmation {
                LaunchAffirmationView()
                    .transition(.opacity)
            } else {
                AppShellView()
                    .transition(.opacity)
            }
        }
        .task(id: isShowingLaunchAffirmation) {
            guard isShowingLaunchAffirmation else { return }

            try? await Task.sleep(nanoseconds: LaunchAffirmationConfiguration.durationNanoseconds)
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                isShowingLaunchAffirmation = false
            }
        }
    }
}

private enum LaunchAffirmationConfiguration {
    static let durationNanoseconds: UInt64 = 4_000_000_000
    static let skipArgument = "SKIP_LAUNCH_AFFIRMATION"

    static var shouldSkip: Bool {
        ProcessInfo.processInfo.arguments.contains(skipArgument)
    }
}

#Preview("Content Launch") {
    ContentView(showLaunchAffirmation: true)
        .modelContainer(PreviewCatalog.populatedApp)
}

#Preview("Content Shell") {
    ContentView(showLaunchAffirmation: false)
        .modelContainer(PreviewCatalog.populatedApp)
}
```

## File: `LIFE-IN-SYNC/DashboardView.swift`

```swift
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Binding var selectedModule: AppModule
    @Query private var habits: [Habit]
    @Query private var habitEntries: [HabitEntry]
    @Query private var tasks: [TaskItem]
    @Query private var events: [CalendarEvent]
    @Query private var supplyItems: [SupplyItem]
    @Query private var expenses: [ExpenseRecord]
    @Query private var workoutSessions: [WorkoutSession]
    @Query private var studyEntries: [StudyEntry]
    @Query private var swingRecords: [SwingRecord]

    private let allModules: [AppModule] = [.habitStack, .taskProtocol, .calendar, .supplyList, .capitalCore, .ironTemple, .bibleStudy, .garage]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DashboardSection(title: "Daily Focus") {
                    DashboardHeroCard(
                        keyMetricTitle: "Open Tasks",
                        keyMetricValue: "\(openTasksCount)"
                    )
                }

                DashboardSection(title: "Module Pulse") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(rankedModules) { module in
                                DashboardModuleEntryCard(
                                    module: module,
                                    progressSummary: statusText(for: module),
                                    urgencyLabel: urgencyText(for: module),
                                    importanceLabel: importanceText(for: module)
                                ) {
                                    selectedModule = module
                                }
                                .frame(width: 230)
                            }
                        }
                    }
                }

                DashboardSection(title: "Timeline + Quiet Alerts") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        DashboardStatCard(
                            module: .habitStack,
                            title: "Habits",
                            value: "\(completedHabitsToday)",
                            detail: "completed today",
                            accessibilityID: "dashboard-stat-habits"
                        )
                        DashboardStatCard(
                            module: .taskProtocol,
                            title: "Tasks",
                            value: "\(openTasksCount)",
                            detail: "open",
                            accessibilityID: "dashboard-stat-tasks"
                        )
                        DashboardStatCard(
                            module: .calendar,
                            title: "Events",
                            value: "\(eventsTodayCount)",
                            detail: "scheduled today",
                            accessibilityID: "dashboard-stat-events"
                        )
                        DashboardStatCard(
                            module: .supplyList,
                            title: "Items",
                            value: "\(remainingSupplyCount)",
                            detail: "remaining to buy",
                            accessibilityID: "dashboard-stat-items"
                        )
                    }
                }
            }
            .padding()
        }
        .background(AppModule.dashboard.theme.screenGradient)
    }

    private var completedHabitsToday: Int {
        habits.filter { habit in
            let progress = habitEntries
                .filter { $0.habitID == habit.id && Calendar.current.isDateInToday($0.loggedAt) }
                .reduce(0) { $0 + $1.count }
            return progress >= habit.targetCount
        }.count
    }

    private var openTasksCount: Int {
        tasks.filter { $0.isCompleted == false }.count
    }

    private var eventsTodayCount: Int {
        events.filter { Calendar.current.isDateInToday($0.startDate) }.count
    }

    private var remainingSupplyCount: Int {
        supplyItems.filter { $0.isPurchased == false }.count
    }

    private var currentMonthSpend: Double {
        expenses
            .filter { Calendar.current.isDate($0.recordedAt, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    private var workoutSessionsThisWeek: Int {
        workoutSessions.filter {
            Calendar.current.isDate($0.performedAt, equalTo: .now, toGranularity: .weekOfYear)
        }.count
    }

    private var rankedModules: [AppModule] {
        allModules.sorted { lhs, rhs in
            let lhsUrgency = urgencyScore(for: lhs)
            let rhsUrgency = urgencyScore(for: rhs)
            if lhsUrgency != rhsUrgency {
                return lhsUrgency > rhsUrgency
            }

            let lhsImportance = importanceScore(for: lhs)
            let rhsImportance = importanceScore(for: rhs)
            if lhsImportance != rhsImportance {
                return lhsImportance > rhsImportance
            }

            // Final deterministic tie-breaker: fall back to original allModules order
            let lhsIndex = allModules.firstIndex(of: lhs) ?? Int.max
            let rhsIndex = allModules.firstIndex(of: rhs) ?? Int.max
            return lhsIndex < rhsIndex
        }
    }

    private func statusText(for module: AppModule) -> String {
        switch module {
        case .dashboard:
            "Home"
        case .habitStack:
            "\(completedHabitsToday) completed today"
        case .taskProtocol:
            "\(openTasksCount) open"
        case .calendar:
            "\(eventsTodayCount) today"
        case .supplyList:
            "\(remainingSupplyCount) remaining"
        case .capitalCore:
            currentMonthSpend.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        case .ironTemple:
            "\(workoutSessionsThisWeek) sessions this week"
        case .bibleStudy:
            "\(studyEntries.count) entries"
        case .garage:
            "\(swingRecords.count) records"
        }
    }

    private func urgencyScore(for module: AppModule) -> Int {
        switch module {
        case .taskProtocol:
            min(openTasksCount, 10)
        case .supplyList:
            min(remainingSupplyCount, 10)
        case .calendar:
            max(0, 5 - eventsTodayCount)
        case .habitStack:
            max(0, 5 - completedHabitsToday)
        case .capitalCore, .ironTemple, .bibleStudy, .garage, .dashboard:
            2
        }
    }

    private func importanceScore(for module: AppModule) -> Int {
        switch module {
        case .habitStack, .taskProtocol, .calendar, .supplyList:
            3
        case .capitalCore, .ironTemple:
            2
        case .bibleStudy, .garage:
            1
        case .dashboard:
            0
        }
    }

    private func urgencyText(for module: AppModule) -> String {
        let rawScore = urgencyScore(for: module)
        let normalizedScore: Int
        switch module {
        case .calendar, .habitStack:
            // These modules currently cap urgency at 5; scale to a 0–10 range for text mapping.
            normalizedScore = rawScore * 2
        default:
            normalizedScore = rawScore
        }

        if normalizedScore >= 7 { return "Urgency: High" }
        if normalizedScore >= 4 { return "Urgency: Medium" }
        return "Urgency: Low"
    }

    private func importanceText(for module: AppModule) -> String {
        switch importanceScore(for: module) {
        case 3:
            "Importance: Core"
        case 2:
            "Importance: High"
        default:
            "Importance: Support"
        }
    }
}

private struct DashboardHeroCard: View {
    let keyMetricTitle: String
    let keyMetricValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.headline)
            Text("Progress-first routing with quiet urgency.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(keyMetricTitle)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(keyMetricValue)
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct DashboardSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            content
        }
    }
}

private struct DashboardModuleEntryCard: View {
    let module: AppModule
    let progressSummary: String
    let urgencyLabel: String
    let importanceLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: module.systemImage)
                    .foregroundStyle(module.theme.primary)
                    .frame(width: 32, height: 32)
                    .background(module.theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(module.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(progressSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(urgencyLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(importanceLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard-module-\(module.rawValue)")
    }
}

private struct DashboardStatCard: View {
    let module: AppModule
    let title: String
    let value: String
    let detail: String
    let accessibilityID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(module.theme.primary.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityID)
    }
}

#Preview("Dashboard Empty") {
    PreviewScreenContainer {
        DashboardView(selectedModule: .constant(.dashboard))
    }
    .modelContainer(PreviewCatalog.emptyApp)
}

#Preview("Dashboard Live") {
    PreviewScreenContainer {
        DashboardView(selectedModule: .constant(.dashboard))
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
```

## File: `LIFE-IN-SYNC/GarageAnalysis.swift`

```swift
import AVFoundation
import Foundation
import Vision

private struct GaragePoseCoordinateMapper {
    let isMirrored: Bool
    let invertY: Bool

    init(isMirrored: Bool = false, invertY: Bool = true) {
        self.isMirrored = isMirrored
        self.invertY = invertY
    }

    func map(_ location: CGPoint) -> CGPoint {
        let clampedX = min(max(location.x, 0), 1)
        let clampedY = min(max(location.y, 0), 1)
        let mappedX = isMirrored ? (1 - clampedX) : clampedX
        let mappedY = invertY ? (1 - clampedY) : clampedY
        return CGPoint(x: mappedX, y: mappedY)
    }
}

private struct GarageWeightedPointSmoother {
    private let weights: [Double]
    private let lowConfidencePenalty: Double
    private var history: [SwingJointName: [SwingJoint]] = [:]

    init(weights: [Double] = [1, 2, 3, 2, 1], lowConfidencePenalty: Double = 0.35) {
        self.weights = weights
        self.lowConfidencePenalty = lowConfidencePenalty
    }

    mutating func smooth(frame: SwingFrame) -> SwingFrame {
        var smoothedJoints: [SwingJoint] = []
        smoothedJoints.reserveCapacity(frame.joints.count)

        for joint in frame.joints {
            var samples = history[joint.name, default: []]
            samples.append(joint)
            if samples.count > weights.count {
                samples.removeFirst(samples.count - weights.count)
            }

            history[joint.name] = samples
            smoothedJoints.append(weightedAverage(for: joint.name, with: samples))
        }

        return SwingFrame(timestamp: frame.timestamp, joints: smoothedJoints, confidence: frame.confidence)
    }

    private func weightedAverage(for name: SwingJointName, with samples: [SwingJoint]) -> SwingJoint {
        var x = 0.0
        var y = 0.0
        var confidence = 0.0
        var totalWeight = 0.0
        let weightSlice = Array(weights.suffix(samples.count))

        for (sample, baseWeight) in zip(samples, weightSlice) {
            let confidenceScale = max(lowConfidencePenalty, sample.confidence)
            let weight = baseWeight * confidenceScale
            x += sample.x * weight
            y += sample.y * weight
            confidence += sample.confidence * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else {
            return samples.last ?? SwingJoint(name: name, x: 0, y: 0, confidence: 0)
        }

        return SwingJoint(
            name: name,
            x: x / totalWeight,
            y: y / totalWeight,
            confidence: confidence / totalWeight
        )
    }
}

private struct GarageHandKinematicSample {
    let index: Int
    let position: CGPoint
    let velocity: CGVector
    let speed: Double
}

private enum GaragePathBuilder {
    static func centripetalCatmullRom(points: [CGPoint], samplesPerSegment: Int = 10) -> [CGPoint] {
        guard points.count >= 2 else { return points }
        guard points.count > 2 else { return points }

        var output: [CGPoint] = []
        output.reserveCapacity((points.count - 1) * samplesPerSegment)

        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            let segment = centripetalSegment(p0: p0, p1: p1, p2: p2, p3: p3, samples: max(samplesPerSegment, 2))
            if i > 0 {
                output.append(contentsOf: segment.dropFirst())
            } else {
                output.append(contentsOf: segment)
            }
        }

        return output
    }

    private static func centripetalSegment(
        p0: CGPoint,
        p1: CGPoint,
        p2: CGPoint,
        p3: CGPoint,
        samples: Int
    ) -> [CGPoint] {
        let alpha = 0.5
        let t0 = 0.0
        let t1 = t0 + parameterDistance(from: p0, to: p1, alpha: alpha)
        let t2 = t1 + parameterDistance(from: p1, to: p2, alpha: alpha)
        let t3 = t2 + parameterDistance(from: p2, to: p3, alpha: alpha)
        guard t1 < t2, t0 < t1, t2 < t3 else { return [p1, p2] }

        var points: [CGPoint] = []
        points.reserveCapacity(samples + 1)
        for step in 0...samples {
            let tau = Double(step) / Double(samples)
            let t = t1 + ((t2 - t1) * tau)
            let a1 = lerp(from: p0, to: p1, t0: t0, t1: t1, t: t)
            let a2 = lerp(from: p1, to: p2, t0: t1, t1: t2, t: t)
            let a3 = lerp(from: p2, to: p3, t0: t2, t1: t3, t: t)
            let b1 = lerp(from: a1, to: a2, t0: t0, t1: t2, t: t)
            let b2 = lerp(from: a2, to: a3, t0: t1, t1: t3, t: t)
            points.append(lerp(from: b1, to: b2, t0: t1, t1: t2, t: t))
        }
        return points
    }

    private static func parameterDistance(from start: CGPoint, to end: CGPoint, alpha: Double) -> Double {
        let distance = max(GarageAnalysisPipeline.distance(from: start, to: end), 1e-6)
        return pow(distance, alpha)
    }

    private static func lerp(from start: CGPoint, to end: CGPoint, t0: Double, t1: Double, t: Double) -> CGPoint {
        guard abs(t1 - t0) > 1e-9 else { return start }
        let weight = (t - t0) / (t1 - t0)
        return CGPoint(x: start.x + (end.x - start.x) * weight, y: start.y + (end.y - start.y) * weight)
    }
}

struct GarageAnalysisOutput {
    let frameRate: Double
    let swingFrames: [SwingFrame]
    let keyFrames: [KeyFrame]
    let handAnchors: [HandAnchor]
    let pathPoints: [PathPoint]
    let analysisResult: AnalysisResult
}

struct GarageVideoAssetMetadata: Equatable {
    let duration: Double
    let frameRate: Double
    let naturalSize: CGSize
}

enum GarageReviewFrameSourceState: Equatable {
    case video
    case poseFallback
    case recoveryNeeded
}

enum GarageResolvedReviewVideoOrigin: String, Equatable {
    case reviewMasterStorage
    case reviewMasterBookmark
    case legacyMediaStorage
    case legacyMediaBookmark
    case exportStorage
    case exportBookmark
}

struct GarageResolvedReviewVideo: Equatable {
    let url: URL
    let origin: GarageResolvedReviewVideoOrigin
}

struct GarageInsightMetric: Identifiable, Equatable {
    let title: String
    let value: String
    let detail: String

    var id: String { title }
}

struct GarageInsightReport: Equatable {
    let readiness: String
    let summary: String
    let highlights: [String]
    let issues: [String]
    let metrics: [GarageInsightMetric]

    var isReady: Bool {
        readiness == "Ready"
    }
}

enum GarageWorkflowStatus: String, Equatable {
    case incomplete = "Incomplete"
    case complete = "Complete"
    case needsAttention = "Needs Attention"
}

enum GarageWorkflowStage: String, CaseIterable, Identifiable {
    case importVideo
    case validateKeyframes
    case markAnchors
    case reviewInsights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .importVideo:
            "Import Video"
        case .validateKeyframes:
            "Validate Keyframes"
        case .markAnchors:
            "Mark 8 Grip Anchors"
        case .reviewInsights:
            "Review Insights"
        }
    }
}

struct GarageWorkflowStageState: Identifiable, Equatable {
    let stage: GarageWorkflowStage
    let status: GarageWorkflowStatus
    let summary: String
    let actionLabel: String

    var id: GarageWorkflowStage { stage }
}

struct GarageWorkflowNextAction: Equatable {
    let title: String
    let body: String
    let actionLabel: String
    let stage: GarageWorkflowStage?
}

struct GarageWorkflowProgress: Equatable {
    let stages: [GarageWorkflowStageState]
    let nextAction: GarageWorkflowNextAction

    var completedCount: Int {
        stages.filter { $0.status == .complete }.count
    }
}

enum GarageReliabilityStatus: String, Equatable {
    case trusted = "Trusted"
    case review = "Review"
    case provisional = "Provisional"
}

struct GarageReliabilityCheck: Identifiable, Equatable {
    let title: String
    let passed: Bool
    let detail: String

    var id: String { title }
}

struct GarageReliabilityReport: Equatable {
    let score: Int
    let status: GarageReliabilityStatus
    let summary: String
    let checks: [GarageReliabilityCheck]

    var needsAttention: Bool {
        status != .trusted
    }
}

enum GarageCoachingSeverity: String, Equatable {
    case positive
    case info
    case caution
}

struct GarageCoachingCue: Identifiable, Equatable {
    let title: String
    let message: String
    let severity: GarageCoachingSeverity

    var id: String { title }
}

struct GarageCoachingReport: Equatable {
    let headline: String
    let confidenceLabel: String
    let cues: [GarageCoachingCue]
    let blockers: [String]
    let nextBestAction: String
}

enum GarageInsights {
    static func report(for record: SwingRecord) -> GarageInsightReport {
        let baseSummary = record.analysisResult?.summary ?? "Swing analysis is in progress."
        let baseHighlights = record.analysisResult?.highlights ?? []
        var highlights = baseHighlights
        var issues = record.analysisResult?.issues ?? []

        let keyframeCount = record.keyFrames.count
        let anchorCount = record.handAnchors.count
        let adjustedCount = record.keyFrames.filter { $0.source == .adjusted }.count
        let pathReady = record.pathPoints.isEmpty == false

        let readiness: String
        if keyframeCount < SwingPhase.allCases.count {
            readiness = "Keyframes Incomplete"
            issues.append("The detected swing phases are incomplete, so timing metrics are partial.")
        } else if anchorCount < SwingPhase.allCases.count {
            readiness = "Awaiting Anchors"
            issues.append("Complete all eight grip anchors to unlock full path-derived measurements.")
        } else if pathReady == false {
            readiness = "Path Unavailable"
            issues.append("All anchors are present, but the path was not generated.")
        } else if record.keyframeValidationStatus == .flagged {
            readiness = "Review Flagged"
            issues.append("Keyframe validation is flagged, so treat the derived metrics as provisional.")
        } else {
            readiness = "Ready"
        }

        if adjustedCount > 0 {
            highlights.append("\(adjustedCount) keyframe\(adjustedCount == 1 ? "" : "s") manually refined after auto-detection.")
        }

        let orderedKeyframes = record.keyFrames.sorted { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }
        let frameIndexes = orderedKeyframes.map(\.frameIndex)
        if frameIndexes != frameIndexes.sorted() {
            issues.append("The saved keyframe order is no longer strictly increasing. Recheck the swing checkpoints.")
        }

        let timingMetrics = timingMetrics(for: record)
        let anchorMetrics = anchorMetrics(for: record)
        let coverageMetrics = coverageMetrics(for: record)
        let metrics = timingMetrics + anchorMetrics + coverageMetrics

        if let tempoMetric = metrics.first(where: { $0.title == "Tempo" }) {
            highlights.append("Current tempo profile is \(tempoMetric.value) with the existing checkpoints.")
        }

        if let returnMetric = metrics.first(where: { $0.title == "Impact Return" }) {
            highlights.append("Hands return to \(returnMetric.value) at impact relative to the address position.")
        }

        let summary: String
        if readiness == "Ready" {
            summary = "\(baseSummary) Full anchor coverage and path generation are complete, so the output layer is ready for review."
        } else if anchorCount > 0 {
            summary = "\(baseSummary) \(anchorCount) of \(SwingPhase.allCases.count) grip anchors are saved so far."
        } else {
            summary = baseSummary
        }

        return GarageInsightReport(
            readiness: readiness,
            summary: summary,
            highlights: uniqueStrings(highlights),
            issues: uniqueStrings(issues),
            metrics: metrics
        )
    }

    private static func timingMetrics(for record: SwingRecord) -> [GarageInsightMetric] {
        let backswing = duration(from: .address, to: .topOfBackswing, in: record)
        let downswing = duration(from: .topOfBackswing, to: .impact, in: record)
        let takeaway = duration(from: .address, to: .takeaway, in: record)

        var metrics: [GarageInsightMetric] = []
        metrics.append(
            GarageInsightMetric(
                title: "Takeaway",
                value: formattedSeconds(takeaway),
                detail: "Time from setup to takeaway."
            )
        )
        metrics.append(
            GarageInsightMetric(
                title: "Backswing",
                value: formattedSeconds(backswing),
                detail: "Time from address to the top of the swing."
            )
        )
        metrics.append(
            GarageInsightMetric(
                title: "Downswing",
                value: formattedSeconds(downswing),
                detail: "Time from the top of the swing to impact."
            )
        )

        if downswing > 0 {
            let tempo = backswing / downswing
            metrics.append(
                GarageInsightMetric(
                    title: "Tempo",
                    value: String(format: "%.2f:1", tempo),
                    detail: "Backswing to downswing timing ratio."
                )
            )
        }

        let averageConfidence = record.swingFrames.isEmpty
            ? 0
            : record.swingFrames.map(\.confidence).reduce(0, +) / Double(record.swingFrames.count)
        metrics.append(
            GarageInsightMetric(
                title: "Pose Confidence",
                value: String(format: "%.0f%%", averageConfidence * 100),
                detail: "Average confidence across sampled pose frames."
            )
        )
        return metrics
    }

    private static func anchorMetrics(for record: SwingRecord) -> [GarageInsightMetric] {
        guard record.pathPoints.isEmpty == false else {
            return []
        }

        var metrics: [GarageInsightMetric] = []
        if let span = pathSpan(for: record.pathPoints) {
            metrics.append(
                GarageInsightMetric(
                    title: "Path Window",
                    value: "\(span.width)% × \(span.height)%",
                    detail: "Normalized width and height of the traced grip path."
                )
            )
        }

        if let impactReturn = impactReturn(for: record) {
            metrics.append(
                GarageInsightMetric(
                    title: "Impact Return",
                    value: "\(impactReturn)%",
                    detail: "Distance between address and impact hand centers, scaled by shoulder width."
                )
            )
        }

        return metrics
    }

    private static func coverageMetrics(for record: SwingRecord) -> [GarageInsightMetric] {
        let totalPhases = SwingPhase.allCases.count
        let anchorCoverage = Int((Double(record.handAnchors.count) / Double(totalPhases)) * 100)
        let adjustedCount = record.keyFrames.filter { $0.source == .adjusted }.count
        return [
            GarageInsightMetric(
                title: "Anchor Coverage",
                value: "\(anchorCoverage)%",
                detail: "\(record.handAnchors.count) of \(totalPhases) grip checkpoints saved."
            ),
            GarageInsightMetric(
                title: "Adjusted Frames",
                value: "\(adjustedCount)",
                detail: "Keyframes manually moved after the automatic pass."
            )
        ]
    }

    private static func duration(from start: SwingPhase, to end: SwingPhase, in record: SwingRecord) -> Double {
        guard
            let startTime = timestamp(for: start, in: record),
            let endTime = timestamp(for: end, in: record)
        else {
            return 0
        }
        return max(endTime - startTime, 0)
    }

    private static func timestamp(for phase: SwingPhase, in record: SwingRecord) -> Double? {
        guard
            let keyFrame = record.keyFrames.first(where: { $0.phase == phase }),
            record.swingFrames.indices.contains(keyFrame.frameIndex)
        else {
            return nil
        }
        return record.swingFrames[keyFrame.frameIndex].timestamp
    }

    private static func pathSpan(for pathPoints: [PathPoint]) -> (width: Int, height: Int)? {
        guard
            let minX = pathPoints.map(\.x).min(),
            let maxX = pathPoints.map(\.x).max(),
            let minY = pathPoints.map(\.y).min(),
            let maxY = pathPoints.map(\.y).max()
        else {
            return nil
        }

        return (
            width: Int(((maxX - minX) * 100).rounded()),
            height: Int(((maxY - minY) * 100).rounded())
        )
    }

    private static func impactReturn(for record: SwingRecord) -> Int? {
        guard
            let addressFrame = frame(for: .address, in: record),
            let impactFrame = frame(for: .impact, in: record)
        else {
            return nil
        }

        let addressHands = GarageAnalysisPipeline.handCenter(in: addressFrame)
        let impactHands = GarageAnalysisPipeline.handCenter(in: impactFrame)
        let shoulderWidth = GarageAnalysisPipeline.bodyScale(in: addressFrame)
        guard shoulderWidth > 0 else {
            return nil
        }

        let returnDistance = GarageAnalysisPipeline.distance(from: addressHands, to: impactHands)
        return Int(((returnDistance / shoulderWidth) * 100).rounded())
    }

    private static func frame(for phase: SwingPhase, in record: SwingRecord) -> SwingFrame? {
        guard
            let keyFrame = record.keyFrames.first(where: { $0.phase == phase }),
            record.swingFrames.indices.contains(keyFrame.frameIndex)
        else {
            return nil
        }
        return record.swingFrames[keyFrame.frameIndex]
    }

    private static func formattedSeconds(_ value: Double) -> String {
        String(format: "%.2fs", value)
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

enum GarageReliability {
    static func report(for record: SwingRecord) -> GarageReliabilityReport {
        let reviewSource = GarageMediaStore.reviewFrameSource(for: record)
        let hasFrames = record.swingFrames.isEmpty == false
        let reviewReady = reviewSource != .recoveryNeeded && hasFrames
        let hasAllKeyframes = record.keyFrames.count == SwingPhase.allCases.count
        let monotonicKeyframes = GarageWorkflow.keyframeSequenceIsMonotonic(record.keyFrames)
        let validationApproved = record.keyframeValidationStatus == .approved
        let fullAnchorCoverage = record.handAnchors.count == SwingPhase.allCases.count
        let pathGenerated = record.pathPoints.isEmpty == false
        let averageConfidence = record.swingFrames.isEmpty
            ? 0
            : record.swingFrames.map(\.confidence).reduce(0, +) / Double(record.swingFrames.count)
        let confidenceStrong = averageConfidence >= 0.55
        let adjustedFrames = record.keyFrames.filter { $0.source == .adjusted }.count
        let limitedManualAdjustment = adjustedFrames <= 2
        let videoSourceDetail: String

        switch reviewSource {
        case .video:
            videoSourceDetail = "Stored video and sampled pose frames are available."
        case .poseFallback:
            videoSourceDetail = "Stored video is missing, but sampled pose frames can still power checkpoint review."
        case .recoveryNeeded:
            videoSourceDetail = "Garage cannot fully verify this swing until either the stored video or fallback-ready pose frames are available."
        }

        let checks = [
            GarageReliabilityCheck(
                title: "Video Source",
                passed: reviewReady,
                detail: videoSourceDetail
            ),
            GarageReliabilityCheck(
                title: "Keyframe Coverage",
                passed: hasAllKeyframes && monotonicKeyframes,
                detail: hasAllKeyframes && monotonicKeyframes
                    ? "All 8 checkpoints are present in the expected swing order."
                    : "One or more swing checkpoints are missing or out of order."
            ),
            GarageReliabilityCheck(
                title: "Review Status",
                passed: validationApproved,
                detail: validationApproved
                    ? "The keyframe review is approved."
                    : "The keyframe review still needs confirmation before this swing should be treated as trustworthy."
            ),
            GarageReliabilityCheck(
                title: "Grip Coverage",
                passed: fullAnchorCoverage && pathGenerated,
                detail: fullAnchorCoverage && pathGenerated
                    ? "All 8 grip anchors are saved and the path is generated."
                    : "Anchor coverage or path generation is incomplete."
            ),
            GarageReliabilityCheck(
                title: "Pose Confidence",
                passed: confidenceStrong,
                detail: confidenceStrong
                    ? "Average pose confidence is \(String(format: "%.0f%%", averageConfidence * 100))."
                    : "Average pose confidence is only \(String(format: "%.0f%%", averageConfidence * 100)), so detections may be noisy."
            ),
            GarageReliabilityCheck(
                title: "Manual Adjustments",
                passed: limitedManualAdjustment,
                detail: limitedManualAdjustment
                    ? "Manual keyframe changes are limited."
                    : "\(adjustedFrames) checkpoints were manually adjusted, which lowers trust in the automatic pass."
            )
        ]

        let weightedChecks: [(GarageReliabilityCheck, Int)] = Array(zip(checks, [15, 20, 20, 25, 10, 10]))
        let score = weightedChecks.reduce(0) { partial, item in
            partial + (item.0.passed ? item.1 : 0)
        }
        let status: GarageReliabilityStatus
        if score >= 84 {
            status = .trusted
        } else if score >= 50 {
            status = .review
        } else {
            status = .provisional
        }

        let summary: String
        switch status {
        case .trusted:
            summary = "This swing has strong coverage across video, checkpoints, anchors, and path generation."
        case .review:
            summary = "This swing is usable, but one or more checks still need review before you trust the output fully."
        case .provisional:
            summary = "This swing is still provisional. Fix the failed checks before relying on the analysis."
        }

        return GarageReliabilityReport(score: score, status: status, summary: summary, checks: checks)
    }
}

enum GarageCoaching {
    static func report(for record: SwingRecord) -> GarageCoachingReport {
        let insightReport = GarageInsights.report(for: record)
        let reliabilityReport = GarageReliability.report(for: record)

        if reliabilityReport.status == .provisional {
            return GarageCoachingReport(
                headline: "Hold interpretation until the swing is more complete.",
                confidenceLabel: reliabilityReport.status.rawValue,
                cues: [],
                blockers: provisionalBlockers(from: reliabilityReport, insightReport: insightReport),
                nextBestAction: "Fix the failed reliability checks before using coaching cues."
            )
        }

        var cues: [GarageCoachingCue] = []

        if let tempo = metricValue(named: "Tempo", in: insightReport),
           let tempoValue = Double(tempo.replacingOccurrences(of: ":1", with: "")) {
            if tempoValue >= 2.7 && tempoValue <= 3.3 {
                cues.append(
                    GarageCoachingCue(
                        title: "Tempo Is Balanced",
                        message: "Backswing-to-downswing timing is staying in a stable range. Preserve this rhythm as you refine the rest of the motion.",
                        severity: .positive
                    )
                )
            } else if tempoValue > 3.3 {
                cues.append(
                    GarageCoachingCue(
                        title: "Backswing Is Running Long",
                        message: "The current tempo suggests the backswing is taking too long relative to the downswing. Shorten the top slightly before adding more speed.",
                        severity: .caution
                    )
                )
            } else {
                cues.append(
                    GarageCoachingCue(
                        title: "Transition Looks Rushed",
                        message: "The current tempo is compressed. Give the backswing more time so the downswing does not feel abrupt.",
                        severity: .caution
                    )
                )
            }
        }

        if let impactReturn = metricPercentValue(named: "Impact Return", in: insightReport) {
            if impactReturn <= 25 {
                cues.append(
                    GarageCoachingCue(
                        title: "Impact Return Is Tight",
                        message: "Your hands are returning close to the address position at impact. Keep that repeatable reference while refining other pieces.",
                        severity: .positive
                    )
                )
            } else if impactReturn >= 45 {
                cues.append(
                    GarageCoachingCue(
                        title: "Impact Return Is Drifting",
                        message: "Hand return at impact is far from address. Recheck setup and transition control before trusting strike-direction feedback.",
                        severity: .caution
                    )
                )
            } else {
                cues.append(
                    GarageCoachingCue(
                        title: "Impact Return Is Usable",
                        message: "The current return distance is workable, but it still leaves room for a tighter delivery into impact.",
                        severity: .info
                    )
                )
            }
        }

        if let pathWindow = metricWindow(named: "Path Window", in: insightReport) {
            if pathWindow.width >= 35 || pathWindow.height >= 55 {
                cues.append(
                    GarageCoachingCue(
                        title: "Hand Path Is Expanding",
                        message: "The current grip path window is relatively large. Keep the motion simpler before layering in more speed or shape changes.",
                        severity: .caution
                    )
                )
            } else if pathWindow.width <= 18 && pathWindow.height <= 28 {
                cues.append(
                    GarageCoachingCue(
                        title: "Hand Path Looks Compact",
                        message: "The current path stays fairly compact through the measured checkpoints. That gives you a clean baseline to repeat.",
                        severity: .positive
                    )
                )
            } else {
                cues.append(
                    GarageCoachingCue(
                        title: "Hand Path Needs Monitoring",
                        message: "The current path shape is readable, but keep comparing it against future swings before making a bigger change from this alone.",
                        severity: .info
                    )
                )
            }
        }

        if let adjustedFrames = metricIntegerValue(named: "Adjusted Frames", in: insightReport), adjustedFrames >= 3 {
            cues.append(
                GarageCoachingCue(
                    title: "Heavy Manual Review",
                    message: "\(adjustedFrames) keyframes were manually adjusted. Treat this coaching as directional until the automatic pass becomes more stable.",
                    severity: .caution
                )
            )
        }

        let blockers = reliabilityReport.status == .review
            ? reviewBlockers(from: reliabilityReport, insightReport: insightReport)
            : []

        let sortedCues = cues.sorted { lhs, rhs in
            severityPriority(lhs.severity) > severityPriority(rhs.severity)
        }

        let headline: String
        if let topCue = sortedCues.first {
            headline = topCue.title
        } else {
            headline = "The swing has usable data, but no strong coaching cue stands out yet."
        }

        let nextBestAction: String
        if reliabilityReport.status == .review {
            nextBestAction = "Use the cues directionally, but resolve the review notes before treating them as final."
        } else if let cautionCue = sortedCues.first(where: { $0.severity == .caution }) {
            nextBestAction = cautionCue.message
        } else {
            nextBestAction = "Keep building comparable swings so the strongest patterns become easier to trust."
        }

        return GarageCoachingReport(
            headline: headline,
            confidenceLabel: reliabilityReport.status.rawValue,
            cues: Array(sortedCues.prefix(3)),
            blockers: blockers,
            nextBestAction: nextBestAction
        )
    }

    private static func provisionalBlockers(
        from reliabilityReport: GarageReliabilityReport,
        insightReport: GarageInsightReport
    ) -> [String] {
        let failedChecks = reliabilityReport.checks
            .filter { $0.passed == false }
            .map(\.detail)
        return Array((failedChecks + insightReport.issues).prefix(3))
    }

    private static func reviewBlockers(
        from reliabilityReport: GarageReliabilityReport,
        insightReport: GarageInsightReport
    ) -> [String] {
        let failedChecks = reliabilityReport.checks
            .filter { $0.passed == false }
            .map(\.detail)
        return Array((failedChecks + insightReport.issues).prefix(2))
    }

    private static func metricValue(named title: String, in report: GarageInsightReport) -> String? {
        report.metrics.first(where: { $0.title == title })?.value
    }

    private static func metricPercentValue(named title: String, in report: GarageInsightReport) -> Int? {
        guard let value = metricValue(named: title, in: report)?
            .replacingOccurrences(of: "%", with: "") else {
            return nil
        }
        return Int(value)
    }

    private static func metricIntegerValue(named title: String, in report: GarageInsightReport) -> Int? {
        guard let value = metricValue(named: title, in: report) else {
            return nil
        }
        return Int(value)
    }

    private static func metricWindow(named title: String, in report: GarageInsightReport) -> (width: Int, height: Int)? {
        guard let value = metricValue(named: title, in: report) else {
            return nil
        }
        let pieces = value.components(separatedBy: "×").map {
            $0.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        }
        guard pieces.count == 2, let width = Int(pieces[0]), let height = Int(pieces[1]) else {
            return nil
        }
        return (width, height)
    }

    private static func severityPriority(_ severity: GarageCoachingSeverity) -> Int {
        switch severity {
        case .caution:
            3
        case .positive:
            2
        case .info:
            1
        }
    }
}

enum GarageWorkflow {
    static func progress(for record: SwingRecord) -> GarageWorkflowProgress {
        let insightReport = GarageInsights.report(for: record)
        let reliabilityReport = GarageReliability.report(for: record)
        let stages = [
            importStage(for: record),
            keyframeStage(for: record),
            anchorStage(for: record),
            insightStage(for: record, insightReport: insightReport, reliabilityReport: reliabilityReport)
        ]

        let prioritizedStage = stages.first(where: { $0.status == .needsAttention })
            ?? stages.first(where: { $0.status == .incomplete })

        let nextAction: GarageWorkflowNextAction
        if let prioritizedStage {
            nextAction = GarageWorkflowNextAction(
                title: prioritizedStage.stage.title,
                body: prioritizedStage.summary,
                actionLabel: prioritizedStage.actionLabel,
                stage: prioritizedStage.stage
            )
        } else {
            nextAction = GarageWorkflowNextAction(
                title: "Workflow Complete",
                body: "All four Garage stages are complete. Review the current insight output and only revisit earlier stages if reliability issues appear.",
                actionLabel: "Review insights",
                stage: .reviewInsights
            )
        }

        return GarageWorkflowProgress(stages: stages, nextAction: nextAction)
    }

    private static func importStage(for record: SwingRecord) -> GarageWorkflowStageState {
        let hasVideoReference = record.preferredReviewFilename != nil
            || record.reviewMasterBookmark != nil
            || record.mediaFileBookmark != nil
            || record.exportAssetBookmark != nil
        let hasFrames = record.swingFrames.isEmpty == false
        let reviewSource = GarageMediaStore.reviewFrameSource(for: record)

        let status: GarageWorkflowStatus
        let summary: String
        let actionLabel: String

        if hasVideoReference == false, hasFrames == false {
            status = .incomplete
            summary = "Import one swing video to initialize Garage."
            actionLabel = "Import video"
        } else if hasFrames == false {
            status = .needsAttention
            summary = "The video reference exists, but Garage cannot currently use it for the workflow."
            actionLabel = "Re-import video"
        } else if reviewSource == .recoveryNeeded {
            status = .complete
            summary = "Sampled pose frames are still available, so Garage can review checkpoints with a fallback pose view while the stored video is recovered."
            actionLabel = "Pose fallback ready"
        } else {
            status = .complete
            summary = "A swing video is available and sampled pose frames were generated."
            actionLabel = "Video ready"
        }

        return GarageWorkflowStageState(stage: .importVideo, status: status, summary: summary, actionLabel: actionLabel)
    }

    private static func keyframeStage(for record: SwingRecord) -> GarageWorkflowStageState {
        let hasAllKeyframes = record.keyFrames.count == SwingPhase.allCases.count
        let keyframesMonotonic = keyframeSequenceIsMonotonic(record.keyFrames)

        let status: GarageWorkflowStatus
        let summary: String
        let actionLabel: String

        if hasAllKeyframes == false {
            status = .incomplete
            summary = "Garage needs all 8 swing checkpoints before the rest of the workflow can be trusted."
            actionLabel = "Finish keyframes"
        } else if record.keyframeValidationStatus == .flagged || keyframesMonotonic == false {
            status = .needsAttention
            summary = "Review the saved keyframes before trusting anchors or downstream insights."
            actionLabel = "Review keyframes"
        } else if record.keyframeValidationStatus == .approved {
            status = .complete
            summary = "All 8 keyframes are present and the current checkpoint review is approved."
            actionLabel = "Keyframes approved"
        } else {
            status = .incomplete
            summary = "All 8 keyframes exist, but they are still pending review."
            actionLabel = "Approve keyframes"
        }

        return GarageWorkflowStageState(stage: .validateKeyframes, status: status, summary: summary, actionLabel: actionLabel)
    }

    private static func anchorStage(for record: SwingRecord) -> GarageWorkflowStageState {
        let uniquePhases = Set(record.handAnchors.map(\.phase))
        let hasAllAnchors = record.handAnchors.count == SwingPhase.allCases.count
        let uniqueCoverage = uniquePhases.count == record.handAnchors.count

        let status: GarageWorkflowStatus
        let summary: String
        let actionLabel: String

        if hasAllAnchors == false {
            let remaining = max(SwingPhase.allCases.count - record.handAnchors.count, 0)
            status = .incomplete
            summary = "\(remaining) grip anchor\(remaining == 1 ? "" : "s") still need to be marked."
            actionLabel = "Place anchors"
        } else if uniqueCoverage == false || record.pathPoints.isEmpty {
            status = .needsAttention
            summary = "Anchor coverage is inconsistent or the path did not generate after all 8 anchors were placed."
            actionLabel = "Review anchors"
        } else {
            status = .complete
            summary = "All 8 grip anchors are saved and the hand path is ready for review."
            actionLabel = "Anchors complete"
        }

        return GarageWorkflowStageState(stage: .markAnchors, status: status, summary: summary, actionLabel: actionLabel)
    }

    private static func insightStage(
        for record: SwingRecord,
        insightReport: GarageInsightReport,
        reliabilityReport: GarageReliabilityReport
    ) -> GarageWorkflowStageState {
        let priorStagesComplete = importStage(for: record).status == .complete
            && keyframeStage(for: record).status == .complete
            && anchorStage(for: record).status == .complete

        let status: GarageWorkflowStatus
        let summary: String
        let actionLabel: String

        if priorStagesComplete == false {
            status = .incomplete
            summary = "Insights unlock after the earlier workflow stages are complete."
            actionLabel = "Finish earlier steps"
        } else if insightReport.isReady == false || insightReport.issues.isEmpty == false || reliabilityReport.needsAttention {
            status = .needsAttention
            summary = "Insights are available, but reliability checks still need review before you treat them as final."
            actionLabel = "Review insight notes"
        } else {
            status = .complete
            summary = "The workflow is complete and the current insight output is ready for review."
            actionLabel = "Review insights"
        }

        return GarageWorkflowStageState(stage: .reviewInsights, status: status, summary: summary, actionLabel: actionLabel)
    }

    static func keyframeSequenceIsMonotonic(_ keyFrames: [KeyFrame]) -> Bool {
        let ordered = keyFrames.sorted { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }
        let frameIndexes = ordered.map(\.frameIndex)
        return frameIndexes == frameIndexes.sorted()
    }
}

enum GarageAnalysisError: LocalizedError {
    case missingVideoTrack
    case insufficientPoseFrames
    case failedToPersistVideo

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack:
            "The selected file does not contain a readable video track."
        case .insufficientPoseFrames:
            "The video did not produce enough pose frames for keyframe detection."
        case .failedToPersistVideo:
            "The selected video could not be copied into local storage."
        }
    }
}

enum GarageMediaStore {
    static func persistVideo(from sourceURL: URL) throws -> URL {
        try persistReviewMaster(from: sourceURL)
    }

    static func persistReviewMaster(from sourceURL: URL) throws -> URL {
        let directoryURL = try garageDirectoryURL(for: .reviewMaster)
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let destinationURL = directoryURL.appendingPathComponent("\(UUID().uuidString).\(ext)")

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            throw GarageAnalysisError.failedToPersistVideo
        }
    }

    static func createExportDerivative(from reviewMasterURL: URL) async -> URL? {
        let asset = AVURLAsset(url: reviewMasterURL)
        guard
            let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality),
            exportSession.supportedFileTypes.contains(.mp4)
        else {
            return nil
        }

        guard let directoryURL = try? garageDirectoryURL(for: .exportAsset) else {
            return nil
        }

        let destinationURL = directoryURL.appendingPathComponent("\(UUID().uuidString).mp4")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }

        switch exportSession.status {
        case .completed:
            return destinationURL
        default:
            try? FileManager.default.removeItem(at: destinationURL)
            return nil
        }
    }

    static func persistedVideoURL(for filename: String?) -> URL? {
        guard let filename, filename.isEmpty == false else {
            return nil
        }

        for kind in [GarageStoredAssetKind.reviewMaster, .legacyRoot, .exportAsset] {
            if let url = persistedAssetURL(for: filename, kind: kind) {
                return url
            }
        }

        return nil
    }

    static func bookmarkData(for url: URL) -> Data? {
        try? url.bookmarkData()
    }

    static func resolvedReviewVideo(for record: SwingRecord) -> GarageResolvedReviewVideo? {
        let candidates: [(GarageResolvedReviewVideoOrigin, URL?)] = [
            (.reviewMasterStorage, record.reviewMasterFilename.flatMap { persistedAssetURL(for: $0, kind: .reviewMaster) }),
            (.reviewMasterBookmark, resolvedBookmarkURL(from: record.reviewMasterBookmark)),
            (.legacyMediaStorage, record.mediaFilename.flatMap { persistedAssetURL(for: $0, kind: .legacyRoot) }),
            (.legacyMediaBookmark, resolvedBookmarkURL(from: record.mediaFileBookmark)),
            (.exportStorage, record.preferredExportFilename.flatMap { persistedAssetURL(for: $0, kind: .exportAsset) }),
            (.exportBookmark, resolvedBookmarkURL(from: record.exportAssetBookmark))
        ]

        for (origin, url) in candidates {
            if let url {
                return GarageResolvedReviewVideo(url: url, origin: origin)
            }
        }

        return nil
    }

    static func resolvedReviewVideoURL(for record: SwingRecord) -> URL? {
        resolvedReviewVideo(for: record)?.url
    }

    static func reviewFrameSource(for record: SwingRecord) -> GarageReviewFrameSourceState {
        if resolvedReviewVideo(for: record) != nil {
            return .video
        }

        if record.swingFrames.isEmpty == false {
            return .poseFallback
        }

        return .recoveryNeeded
    }

    static func resolvedExportVideoURL(for record: SwingRecord) -> URL? {
        if let exportFilename = record.preferredExportFilename,
           let persistedURL = persistedAssetURL(for: exportFilename, kind: .exportAsset) {
            return persistedURL
        }

        return resolvedBookmarkURL(from: record.exportAssetBookmark)
    }

    static func thumbnail(for videoURL: URL, at timestamp: Double, maximumSize: CGSize = CGSize(width: 480, height: 480)) async -> CGImage? {
        await withCheckedContinuation { continuation in
            let asset = AVURLAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = maximumSize
            generator.requestedTimeToleranceAfter = .zero
            generator.requestedTimeToleranceBefore = .zero

            let time = CMTime(seconds: timestamp, preferredTimescale: 600)
            generator.generateCGImageAsynchronously(for: time) { image, _, _ in
                continuation.resume(returning: image.flatMap(normalizedDisplayImage(from:)))
            }
        }
    }

    static func assetMetadata(for videoURL: URL) async -> GarageVideoAssetMetadata? {
        do {
            let asset = AVURLAsset(url: videoURL)
            let duration = try await asset.load(.duration)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                return nil
            }

            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let transformedSize = naturalSize.applying(transform)
            let nominalFrameRate = try await track.load(.nominalFrameRate)

            return GarageVideoAssetMetadata(
                duration: max(CMTimeGetSeconds(duration), 0),
                frameRate: nominalFrameRate > 0 ? Double(nominalFrameRate) : 0,
                naturalSize: CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
            )
        } catch {
            return nil
        }
    }

    private static func persistedAssetURL(for filename: String, kind: GarageStoredAssetKind) -> URL? {
        guard let directoryURL = try? garageDirectoryURL(for: kind) else {
            return nil
        }

        let url = directoryURL.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func resolvedBookmarkURL(from bookmarkData: Data?) -> URL? {
        guard let bookmarkData else {
            return nil
        }

        var isStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        return FileManager.default.fileExists(atPath: resolvedURL.path) ? resolvedURL : nil
    }

    private static func garageDirectoryURL(for kind: GarageStoredAssetKind) throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let rootURL = baseURL.appendingPathComponent("GarageSwingVideos", isDirectory: true)
        let garageURL: URL
        switch kind {
        case .legacyRoot:
            garageURL = rootURL
        case .reviewMaster:
            garageURL = rootURL.appendingPathComponent("ReviewMasters", isDirectory: true)
        case .exportAsset:
            garageURL = rootURL.appendingPathComponent("Exports", isDirectory: true)
        }
        if FileManager.default.fileExists(atPath: garageURL.path) == false {
            try FileManager.default.createDirectory(at: garageURL, withIntermediateDirectories: true)
        }
        return garageURL
    }

    nonisolated private static func normalizedDisplayImage(from image: CGImage) -> CGImage? {
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard
            let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: image.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: image.bitmapInfo.rawValue
            )
        else {
            return image
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage() ?? image
    }
}

private enum GarageStoredAssetKind {
    case legacyRoot
    case reviewMaster
    case exportAsset
}

enum GarageAnalysisPipeline {
    private enum KinematicThresholds {
        static let reversalVelocityEpsilon = 0.015
        static let impactSpeedQuantile = 0.82
        static let impactLowerPathQuantile = 0.62
        static let impactWindow = 2
    }

    static func analyzeVideo(at videoURL: URL) async throws -> GarageAnalysisOutput {
        let asset = AVURLAsset(url: videoURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw GarageAnalysisError.missingVideoTrack
        }

        let duration = try await asset.load(.duration)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let samplingFrameRate = resolvedSamplingFrameRate(from: nominalFrameRate)
        let timestamps = sampledTimestamps(duration: duration, frameRate: samplingFrameRate)
        let extractedFrames = try await extractPoseFrames(from: asset, timestamps: timestamps)
        let smoothedFrames = smooth(frames: extractedFrames)

        guard smoothedFrames.count >= SwingPhase.allCases.count else {
            throw GarageAnalysisError.insufficientPoseFrames
        }

        let keyFrames = detectKeyFrames(from: smoothedFrames)
        let handAnchors = deriveHandAnchors(from: smoothedFrames, keyFrames: keyFrames)
        let pathPoints = generatePathPoints(from: smoothedFrames, samplesPerSegment: 8)
        let analysisResult = AnalysisResult(
            issues: [],
            highlights: [
                "Eight deterministic keyframes detected from normalized pose frames.",
                "\(handAnchors.count) hand checkpoints are aligned to the saved review phases."
            ],
            summary: "Processed \(smoothedFrames.count) frames at \(Int(samplingFrameRate.rounded())) FPS, mapped all eight swing phases, and prepared a review-ready hand path."
        )

        return GarageAnalysisOutput(
            frameRate: samplingFrameRate,
            swingFrames: smoothedFrames,
            keyFrames: keyFrames,
            handAnchors: handAnchors,
            pathPoints: pathPoints,
            analysisResult: analysisResult
        )
    }

    private static func resolvedSamplingFrameRate(from nominalFrameRate: Float) -> Double {
        let baseRate = nominalFrameRate > 0 ? Double(nominalFrameRate) : 30
        return min(max(baseRate, 30), 60)
    }

    private static func sampledTimestamps(duration: CMTime, frameRate: Double) -> [Double] {
        let seconds = max(CMTimeGetSeconds(duration), 0)
        guard seconds > 0 else { return [] }

        let interval = 1 / frameRate
        var timestamps: [Double] = []
        var current: Double = 0
        while current < seconds {
            timestamps.append(current)
            current += interval
        }

        if let last = timestamps.last, seconds - last > 0.01 {
            timestamps.append(seconds)
        }

        return timestamps
    }

    private static func extractPoseFrames(from asset: AVAsset, timestamps: [Double]) async throws -> [SwingFrame] {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 960, height: 960)
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero

        var frames: [SwingFrame] = []
        for timestamp in timestamps {
            try Task.checkCancellation()
            let time = CMTime(seconds: timestamp, preferredTimescale: 600)
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                await Task.yield()
                continue
            }

            if let frame = try detectPoseFrame(from: cgImage, timestamp: timestamp) {
                frames.append(frame)
            }
            await Task.yield()
        }

        return frames
    }

    private static func detectPoseFrame(from cgImage: CGImage, timestamp: Double) throws -> SwingFrame? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return nil
        }

        let recognizedPoints = try observation.recognizedPoints(.all)
        var joints: [SwingJoint] = []

        let mapper = GaragePoseCoordinateMapper(isMirrored: false, invertY: true)
        for jointName in SwingJointName.allCases {
            guard
                let visionName = jointName.visionName,
                let recognizedPoint = recognizedPoints[visionName],
                recognizedPoint.confidence >= 0.15
            else {
                continue
            }
            let mappedPoint = mapper.map(recognizedPoint.location)

            joints.append(
                SwingJoint(
                    name: jointName,
                    x: Double(mappedPoint.x),
                    y: Double(mappedPoint.y),
                    confidence: Double(recognizedPoint.confidence)
                )
            )
        }

        guard hasMinimumDetectionSet(in: joints) else {
            return nil
        }

        let confidence = joints.map(\.confidence).reduce(0, +) / Double(joints.count)
        return SwingFrame(timestamp: timestamp, joints: joints, confidence: confidence)
    }

    private static func hasMinimumDetectionSet(in joints: [SwingJoint]) -> Bool {
        let names = Set(joints.map(\.name))
        let required: Set<SwingJointName> = [.leftShoulder, .rightShoulder, .leftHip, .rightHip, .leftWrist, .rightWrist]
        return required.isSubset(of: names)
    }

    private static func smooth(frames: [SwingFrame]) -> [SwingFrame] {
        var smoother = GarageWeightedPointSmoother()
        return frames.map { smoother.smooth(frame: $0) }
    }

    static func detectKeyFrames(from frames: [SwingFrame]) -> [KeyFrame] {
        let addressIndex = addressIndex(in: frames)
        let topIndex = topOfBackswingIndex(in: frames, fallbackStart: addressIndex + 2)
        let takeawayIndex = takeawayIndex(in: frames, addressIndex: addressIndex, topIndex: topIndex)
        let shaftParallelIndex = shaftParallelIndex(in: frames, addressIndex: addressIndex, takeawayIndex: takeawayIndex, topIndex: topIndex)
        let transitionIndex = transitionIndex(in: frames, topIndex: topIndex)
        let impactIndex = impactIndex(in: frames, addressIndex: addressIndex, transitionIndex: transitionIndex)
        let earlyDownswingIndex = earlyDownswingIndex(in: frames, transitionIndex: transitionIndex, impactIndex: impactIndex)
        let followThroughIndex = followThroughIndex(in: frames, impactIndex: impactIndex)

        return [
            KeyFrame(phase: .address, frameIndex: addressIndex),
            KeyFrame(phase: .takeaway, frameIndex: takeawayIndex),
            KeyFrame(phase: .shaftParallel, frameIndex: shaftParallelIndex),
            KeyFrame(phase: .topOfBackswing, frameIndex: topIndex),
            KeyFrame(phase: .transition, frameIndex: transitionIndex),
            KeyFrame(phase: .earlyDownswing, frameIndex: earlyDownswingIndex),
            KeyFrame(phase: .impact, frameIndex: impactIndex),
            KeyFrame(phase: .followThrough, frameIndex: followThroughIndex)
        ]
    }

    static func deriveHandAnchors(from frames: [SwingFrame], keyFrames: [KeyFrame]) -> [HandAnchor] {
        let orderedKeyFrames = keyFrames.sorted { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }

        return orderedKeyFrames.compactMap { keyFrame in
            guard frames.indices.contains(keyFrame.frameIndex) else {
                return nil
            }

            let center = handCenter(in: frames[keyFrame.frameIndex])
            return HandAnchor(phase: keyFrame.phase, x: center.x, y: center.y)
        }
    }

    static func mergedHandAnchors(
        preserving existingAnchors: [HandAnchor],
        from frames: [SwingFrame],
        keyFrames: [KeyFrame]
    ) -> [HandAnchor] {
        let derivedAnchors = Dictionary(uniqueKeysWithValues: deriveHandAnchors(from: frames, keyFrames: keyFrames).map { ($0.phase, $0) })
        let existingAnchorsByPhase = Dictionary(uniqueKeysWithValues: existingAnchors.map { ($0.phase, $0) })

        return SwingPhase.allCases.compactMap { phase in
            if let existingAnchor = existingAnchorsByPhase[phase], existingAnchor.source == .manual {
                return existingAnchor
            }

            return derivedAnchors[phase] ?? existingAnchorsByPhase[phase]
        }
    }

    static func upsertingHandAnchor(_ anchor: HandAnchor, into anchors: [HandAnchor]) -> [HandAnchor] {
        var updatedAnchors = anchors.filter { $0.phase != anchor.phase }
        updatedAnchors.append(anchor)
        updatedAnchors.sort { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }
        return updatedAnchors
    }

    private static func addressIndex(in frames: [SwingFrame]) -> Int {
        guard frames.count > 1 else {
            return 0
        }

        let searchEnd = min(max(6, frames.count / 4), frames.count - 1)
        let openingFrames = Array(frames[0...searchEnd])
        let kinematicSamples = handKinematics(from: openingFrames)
        let speedByIndex = Dictionary(uniqueKeysWithValues: kinematicSamples.map { ($0.index, $0.speed) })
        let maxSpeed = max(kinematicSamples.map(\.speed).max() ?? 0.001, 0.001)
        let handYs = openingFrames.map { handCenter(in: $0).y }
        let maxHandY = handYs.max() ?? 0
        let minHandY = handYs.min() ?? 0
        let handYSpan = max(maxHandY - minHandY, 0.0001)
        let maxConfidence = max(openingFrames.map(\.confidence).max() ?? 1, 0.0001)

        var bestIndex = 0
        var bestScore = Double.greatestFiniteMagnitude

        for index in 0...searchEnd {
            let frame = frames[index]
            let handCenterPoint = handCenter(in: frame)
            let normalizedSpeed = min((speedByIndex[index] ?? 0) / maxSpeed, 1)
            let raisedHandsPenalty = min(max((maxHandY - handCenterPoint.y) / handYSpan, 0), 1)
            let confidencePenalty = 1 - min(max(frame.confidence / maxConfidence, 0), 1)
            let latenessPenalty = Double(index) / Double(max(searchEnd, 1))
            let score = (normalizedSpeed * 0.50)
                + (raisedHandsPenalty * 0.28)
                + (confidencePenalty * 0.17)
                + (latenessPenalty * 0.05)

            if score < bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        return bestIndex
    }

    private static func topOfBackswingIndex(in frames: [SwingFrame], fallbackStart: Int) -> Int {
        let samples = handKinematics(from: frames)
        guard samples.count >= 4 else {
            return min(max(fallbackStart, frames.count / 3), max(frames.count - 3, 0))
        }

        let searchStart = min(max(fallbackStart, 1), samples.count - 2)
        let searchEnd = max(searchStart + 1, samples.count - 1)
        let range = searchStart..<searchEnd

        let candidate = range.first { index in
            let previous = samples[index - 1].velocity.dx
            let current = samples[index].velocity.dx
            let vertical = abs(samples[index].velocity.dy)
            return previous > KinematicThresholds.reversalVelocityEpsilon
                && current < -KinematicThresholds.reversalVelocityEpsilon
                && vertical < KinematicThresholds.reversalVelocityEpsilon * 2
        }

        if let candidate {
            return samples[candidate - 1].index
        }

        let fallback = range.min { lhs, rhs in
            abs(samples[lhs].velocity.dy) < abs(samples[rhs].velocity.dy)
        }

        return fallback.map { samples[$0].index } ?? min(max(fallbackStart, frames.count / 3), max(frames.count - 3, 0))
    }

    private static func takeawayIndex(in frames: [SwingFrame], addressIndex: Int, topIndex: Int) -> Int {
        let addressHands = handCenter(in: frames[addressIndex])
        let shoulderWidth = bodyScale(in: frames[addressIndex])
        let horizontalThreshold = max(0.03, shoulderWidth * 0.18)

        for index in (addressIndex + 1)..<max(topIndex, addressIndex + 2) {
            let horizontalDisplacement = abs(handCenter(in: frames[index]).x - addressHands.x)
            if horizontalDisplacement >= horizontalThreshold {
                return index
            }
        }

        return min(addressIndex + 1, max(topIndex - 1, addressIndex))
    }

    private static func shaftParallelIndex(in frames: [SwingFrame], addressIndex: Int, takeawayIndex: Int, topIndex: Int) -> Int {
        guard takeawayIndex + 1 < topIndex else {
            return min(takeawayIndex + 1, topIndex)
        }

        let addressHands = handCenter(in: frames[addressIndex])
        let topHands = handCenter(in: frames[topIndex])
        let targetDistance = distance(from: addressHands, to: topHands) * 0.5

        let range = (takeawayIndex + 1)..<topIndex
        return range.min { lhs, rhs in
            let lhsDelta = abs(distance(from: addressHands, to: handCenter(in: frames[lhs])) - targetDistance)
            let rhsDelta = abs(distance(from: addressHands, to: handCenter(in: frames[rhs])) - targetDistance)
            return lhsDelta < rhsDelta
        } ?? min(takeawayIndex + 1, topIndex)
    }

    private static func transitionIndex(in frames: [SwingFrame], topIndex: Int) -> Int {
        let topHands = handCenter(in: frames[topIndex])
        let torsoHeight = torsoHeight(in: frames[topIndex])
        let downwardThreshold = max(0.015, torsoHeight * 0.06)

        for index in (topIndex + 1)..<frames.count {
            let handY = handCenter(in: frames[index]).y
            if handY - topHands.y >= downwardThreshold {
                return index
            }
        }

        return min(topIndex + 1, frames.count - 1)
    }

    private static func earlyDownswingIndex(in frames: [SwingFrame], transitionIndex: Int, impactIndex: Int) -> Int {
        guard transitionIndex + 1 < impactIndex else {
            return max(transitionIndex, impactIndex - 1)
        }

        let latestAllowed = impactIndex - 1
        let transitionHands = handCenter(in: frames[transitionIndex])
        let impactHands = handCenter(in: frames[impactIndex])
        let transitionToImpactDistance = distance(from: transitionHands, to: impactHands)
        let targetDistance = transitionToImpactDistance * 0.35
        let maxDistanceBeforeImpact = transitionToImpactDistance * 0.90
        let impactHandY = impactHands.y
        let kinematicByIndex = Dictionary(uniqueKeysWithValues: handKinematics(from: frames).map { ($0.index, $0) })

        let candidateRange = (transitionIndex + 1)...latestAllowed
        let constrainedCandidates = candidateRange.filter { index in
            let point = handCenter(in: frames[index])
            let traveledDistance = distance(from: transitionHands, to: point)
            guard traveledDistance > 0, traveledDistance <= maxDistanceBeforeImpact else {
                return false
            }

            // Keep early-downswing prior to the near-impact region.
            if point.y > impactHandY * 0.98 {
                return false
            }

            // Require directional commitment into downswing.
            if let sample = kinematicByIndex[index], sample.velocity.dy <= 0 {
                return false
            }

            return true
        }

        if let bestCandidate = constrainedCandidates.min(by: { lhs, rhs in
            let lhsPoint = handCenter(in: frames[lhs])
            let rhsPoint = handCenter(in: frames[rhs])
            let lhsDelta = abs(distance(from: transitionHands, to: lhsPoint) - targetDistance)
            let rhsDelta = abs(distance(from: transitionHands, to: rhsPoint) - targetDistance)
            return lhsDelta < rhsDelta
        }) {
            return bestCandidate
        }

        let fallbackRange = (transitionIndex + 1)...latestAllowed
        return fallbackRange.min { lhs, rhs in
            let lhsDelta = abs(distance(from: transitionHands, to: handCenter(in: frames[lhs])) - targetDistance)
            let rhsDelta = abs(distance(from: transitionHands, to: handCenter(in: frames[rhs])) - targetDistance)
            return lhsDelta < rhsDelta
        } ?? min(transitionIndex + 1, latestAllowed)
    }

    private static func impactIndex(in frames: [SwingFrame], addressIndex _: Int, transitionIndex: Int) -> Int {
        let samples = handKinematics(from: frames)
        guard samples.count >= 4 else { return frames.count - 1 }

        let searchStart = max(transitionIndex + 1, 1)
        guard searchStart < samples.count else { return frames.count - 1 }

        let candidateSamples = Array(samples[searchStart..<samples.count])
        let speeds = candidateSamples.map(\.speed).sorted()
        let yValues = candidateSamples.map { Double($0.position.y) }.sorted()
        guard
            let speedThreshold = quantile(fromSortedValues: speeds, quantile: KinematicThresholds.impactSpeedQuantile),
            let lowerPathY = quantile(fromSortedValues: yValues, quantile: KinematicThresholds.impactLowerPathQuantile)
        else {
            return frames.count - 1
        }

        let validCandidates = candidateSamples.filter { sample in
            sample.speed >= speedThreshold && sample.position.y >= lowerPathY
        }

        if let best = validCandidates.max(by: { smoothedSpeed(at: $0.index, in: samples) < smoothedSpeed(at: $1.index, in: samples) }) {
            return best.index
        }

        return candidateSamples.max(by: { $0.speed < $1.speed })?.index ?? frames.count - 1
    }

    private static func followThroughIndex(in frames: [SwingFrame], impactIndex: Int) -> Int {
        guard impactIndex + 1 < frames.count else {
            return impactIndex
        }

        let range = (impactIndex + 1)..<frames.count
        let candidate = range.min { lhs, rhs in
            handCenter(in: frames[lhs]).y < handCenter(in: frames[rhs]).y
        }

        return candidate ?? frames.count - 1
    }

    static func handCenter(in frame: SwingFrame) -> CGPoint {
        let left = frame.point(named: .leftWrist)
        let right = frame.point(named: .rightWrist)
        return CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
    }

    static func bodyScale(in frame: SwingFrame) -> Double {
        distance(from: frame.point(named: .leftShoulder), to: frame.point(named: .rightShoulder))
    }

    private static func torsoHeight(in frame: SwingFrame) -> Double {
        let shoulders = midpoint(frame.point(named: .leftShoulder), frame.point(named: .rightShoulder))
        let hips = midpoint(frame.point(named: .leftHip), frame.point(named: .rightHip))
        return abs(hips.y - shoulders.y)
    }

    private static func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }

    static func distance(from lhs: CGPoint, to rhs: CGPoint) -> Double {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return sqrt((dx * dx) + (dy * dy))
    }

    static func generatePathPoints(from frames: [SwingFrame], samplesPerSegment: Int = 16) -> [PathPoint] {
        let stabilizedPoints = frames.map { handCenter(in: $0) }
        guard stabilizedPoints.count >= 2 else {
            return []
        }

        let splinePoints = GaragePathBuilder.centripetalCatmullRom(
            points: stabilizedPoints,
            samplesPerSegment: samplesPerSegment
        )

        return splinePoints.enumerated().map { sequence, point in
            PathPoint(sequence: sequence, x: point.x, y: point.y)
        }
    }

    static func generatePathPoints(from anchors: [HandAnchor], samplesPerSegment: Int = 16) -> [PathPoint] {
        let stabilizedPoints = anchors.compactMap { point(from: $0) }
        guard stabilizedPoints.count >= 2 else {
            return []
        }

        let splinePoints = GaragePathBuilder.centripetalCatmullRom(
            points: stabilizedPoints,
            samplesPerSegment: samplesPerSegment
        )

        return splinePoints.enumerated().map { sequence, point in
            PathPoint(sequence: sequence, x: point.x, y: point.y)
        }
    }

    private static func point(from anchor: HandAnchor) -> CGPoint? {
        point(fromValue: anchor)
    }

    private static func point(fromValue value: Any) -> CGPoint? {
        if let point = value as? CGPoint {
            return point
        }

        let mirror = Mirror(reflecting: value)
        var xValue: CGFloat?
        var yValue: CGFloat?

        for child in mirror.children {
            if let point = point(fromValue: child.value) {
                return point
            }

            switch child.label {
            case "x":
                xValue = cgFloat(from: child.value)
            case "y":
                yValue = cgFloat(from: child.value)
            default:
                continue
            }
        }

        if let xValue, let yValue {
            return CGPoint(x: xValue, y: yValue)
        }

        return nil
    }

    private static func cgFloat(from value: Any) -> CGFloat? {
        if let value = value as? CGFloat {
            return value
        }
        if let value = value as? Double {
            return CGFloat(value)
        }
        if let value = value as? Float {
            return CGFloat(value)
        }
        if let value = value as? Int {
            return CGFloat(value)
        }
        return nil
    }
    private static func handKinematics(from frames: [SwingFrame]) -> [GarageHandKinematicSample] {
        guard frames.count >= 2 else { return [] }

        var samples: [GarageHandKinematicSample] = []
        samples.reserveCapacity(frames.count - 1)
        var previousCenter = handCenter(in: frames[0])
        var previousTime = frames[0].timestamp

        for index in 1..<frames.count {
            let currentCenter = handCenter(in: frames[index])
            let currentTime = frames[index].timestamp
            let dt = max(currentTime - previousTime, 1.0 / 240.0)
            let vx = (currentCenter.x - previousCenter.x) / dt
            let vy = (currentCenter.y - previousCenter.y) / dt
            let speed = sqrt((vx * vx) + (vy * vy))
            samples.append(
                GarageHandKinematicSample(
                    index: index,
                    position: currentCenter,
                    velocity: CGVector(dx: vx, dy: vy),
                    speed: speed
                )
            )
            previousCenter = currentCenter
            previousTime = currentTime
        }

        return samples
    }

    private static func quantile(fromSortedValues values: [Double], quantile: Double) -> Double? {
        guard values.isEmpty == false else { return nil }
        let q = min(max(quantile, 0), 1)
        let index = Int((Double(values.count - 1) * q).rounded(.down))
        return values[index]
    }

    private static func smoothedSpeed(at index: Int, in samples: [GarageHandKinematicSample]) -> Double {
        guard let position = samples.firstIndex(where: { $0.index == index }) else { return 0 }
        let start = max(0, position - KinematicThresholds.impactWindow)
        let end = min(samples.count - 1, position + KinematicThresholds.impactWindow)
        let window = samples[start...end]
        let total = window.reduce(0) { $0 + $1.speed }
        return total / Double(window.count)
    }
}

private extension SwingJointName {
    var visionName: VNHumanBodyPoseObservation.JointName? {
        switch self {
        case .nose:
            .nose
        case .leftShoulder:
            .leftShoulder
        case .rightShoulder:
            .rightShoulder
        case .leftElbow:
            .leftElbow
        case .rightElbow:
            .rightElbow
        case .leftWrist:
            .leftWrist
        case .rightWrist:
            .rightWrist
        case .leftHip:
            .leftHip
        case .rightHip:
            .rightHip
        case .leftKnee:
            .leftKnee
        case .rightKnee:
            .rightKnee
        case .leftAnkle:
            .leftAnkle
        case .rightAnkle:
            .rightAnkle
        }
    }
}

extension SwingFrame {
    func point(named name: SwingJointName) -> CGPoint {
        guard let joint = joints.first(where: { $0.name == name }) else {
            return .zero
        }
        return CGPoint(x: joint.x, y: joint.y)
    }
}
```

## File: `LIFE-IN-SYNC/GarageView.swift`

```swift
import AVFoundation
import AVKit
import Combine
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct GarageTimelineMarker: Identifiable {
    let keyFrame: KeyFrame
    let timestamp: Double

    var id: SwingPhase { keyFrame.phase }
}

private struct GarageHandPathSample: Identifiable {
    let id: Int
    let timestamp: Double
    let x: Double
    let y: Double
    let speed: Double

    init(
        id: Int,
        timestamp: Double,
        x: Double,
        y: Double,
        speed: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.speed = speed
    }
}

func garageDeterministicHandPathSampleID(index: Int, timestamp: Double) -> Int {
    let quantizedTimestamp = Int64((timestamp * 1_000_000).rounded())
    let indexBits = UInt64(bitPattern: Int64(index))
    let timestampBits = UInt64(bitPattern: quantizedTimestamp)
    let bytes: [UInt8] = [
        UInt8(truncatingIfNeeded: indexBits),
        UInt8(truncatingIfNeeded: indexBits >> 8),
        UInt8(truncatingIfNeeded: indexBits >> 16),
        UInt8(truncatingIfNeeded: indexBits >> 24),
        UInt8(truncatingIfNeeded: indexBits >> 32),
        UInt8(truncatingIfNeeded: indexBits >> 40),
        UInt8(truncatingIfNeeded: indexBits >> 48),
        UInt8(truncatingIfNeeded: indexBits >> 56),
        UInt8(truncatingIfNeeded: timestampBits),
        UInt8(truncatingIfNeeded: timestampBits >> 8),
        UInt8(truncatingIfNeeded: timestampBits >> 16),
        UInt8(truncatingIfNeeded: timestampBits >> 24),
        UInt8(truncatingIfNeeded: timestampBits >> 32),
        UInt8(truncatingIfNeeded: timestampBits >> 40),
        UInt8(truncatingIfNeeded: timestampBits >> 48),
        UInt8(truncatingIfNeeded: timestampBits >> 56)
    ]

    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
    }

    return Int(truncatingIfNeeded: hash)
}

private extension KeyframeValidationStatus {
    var reviewTint: Color {
        switch self {
        case .pending:
            AppModule.garage.theme.primary
        case .approved:
            .green
        case .flagged:
            .red
        }
    }

    var reviewBackground: Color {
        switch self {
        case .pending:
            AppModule.garage.theme.chipBackground
        case .approved:
            Color.green.opacity(0.12)
        case .flagged:
            Color.red.opacity(0.12)
        }
    }
}

private func garageRecordSelectionKey(for record: SwingRecord) -> String {
    [
        record.createdAt.ISO8601Format(),
        record.title,
        record.preferredReviewFilename ?? "no-review-asset",
        record.preferredExportFilename ?? "no-export-asset"
    ].joined(separator: "::")
}

private func garageHandPathSamples(from frames: [SwingFrame]) -> [GarageHandPathSample] {
    guard frames.count >= 2 else {
        return []
    }

    let smoothedCenters = GarageAnalysisPipeline.generatePathPoints(from: frames, samplesPerSegment: 6).map {
        CGPoint(x: $0.x, y: $0.y)
    }
    guard smoothedCenters.count >= 2 else { return [] }

    return smoothedCenters.enumerated().map { index, point in
        let priorIndex = max(index - 1, 0)
        let nextIndex = min(index + 1, smoothedCenters.count - 1)
        let previousPoint = smoothedCenters[priorIndex]
        let nextPoint = smoothedCenters[nextIndex]
        let speed = GarageAnalysisPipeline.distance(from: previousPoint, to: nextPoint)
        let normalizedT = Double(index) / Double(max(smoothedCenters.count - 1, 1))
        let sourceFrame = min(Int((Double(frames.count - 1) * normalizedT).rounded()), frames.count - 1)

        return GarageHandPathSample(
            id: garageDeterministicHandPathSampleID(index: index, timestamp: frames[sourceFrame].timestamp),
            timestamp: frames[sourceFrame].timestamp,
            x: point.x,
            y: point.y,
            speed: speed
        )
    }
}

struct GarageView: View {
    @Query(sort: \SwingRecord.createdAt, order: .reverse) private var swingRecords: [SwingRecord]
    @State private var isShowingAddRecord = false
    @State private var selectedTab: ModuleHubTab = .records
    @State private var selectedReviewRecordKey: String?

    var body: some View {
        ModuleHubScaffold(
            module: .garage,
            title: "Store swing work without overclaiming analysis.",
            subtitle: "Review swing checkpoints with a calmer, accuracy-first workflow.",
            currentState: "\(swingRecords.count) swing records currently stored.",
            nextAttention: swingRecords.isEmpty ? "Import your first swing video to begin review." : "Use Review to validate checkpoints and refine the current swing.",
            showsCommandCenterChrome: false,
            tabs: [.records, .review],
            selectedTab: $selectedTab
        ) {
            switch selectedTab {
            case .records:
                GarageRecordsTab(records: swingRecords) {
                    presentAddRecord()
                }
            case .review:
                GarageReviewTab(records: swingRecords, selectedRecordKey: $selectedReviewRecordKey)
            default:
                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if selectedTab != .review {
                    ModuleBottomActionBar(
                        theme: AppModule.garage.theme,
                        title: "Add Swing Record",
                        systemImage: "plus"
                    ) {
                        presentAddRecord()
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddRecord) {
            AddSwingRecordSheet(autoPresentPicker: true, autoImportOnSelection: true) { record in
                selectedReviewRecordKey = garageRecordSelectionKey(for: record)
                selectedTab = .review
            }
        }
        .onChange(of: swingRecords.map(garageRecordSelectionKey)) { _, keys in
            guard keys.isEmpty == false else {
                selectedTab = .records
                return
            }

            if selectedTab == .records, selectedReviewRecordKey != nil {
                selectedTab = .review
            }
        }
    }

    private func presentAddRecord() {
        isShowingAddRecord = true
    }
}

private struct GarageRecordsTab: View {
    let records: [SwingRecord]
    let importVideo: () -> Void

    var body: some View {
        ModuleActivityFeedSection(title: "Swing Records") {
            if records.isEmpty {
                GarageEmptyStateView(action: importVideo)
            } else {
                ModuleRowSurface(theme: AppModule.garage.theme) {
                    Text("Capture")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    Text("Import another swing video whenever you want to start a new review pass.")
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                    Button("Import Swing Video", action: importVideo)
                        .buttonStyle(.borderedProminent)
                        .tint(AppModule.garage.theme.primary)
                }

                ForEach(records.prefix(8)) { record in
                    SwingRecordCard(record: record)
                }
            }
        }
    }
}

private struct SwingRecordCard: View {
    let record: SwingRecord

    private var reviewStateLabel: String {
        switch record.keyframeValidationStatus {
        case .approved:
            "Approved"
        case .flagged:
            "Flagged"
        case .pending:
            "Needs Review"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.title)
                .font(.headline)

            if record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Text(record.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: ModuleSpacing.small) {
                GarageReviewStatusPill(status: record.keyframeValidationStatus)

                Text(reviewStateLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppModule.garage.theme.textSecondary)

                Spacer(minLength: 0)

                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct GarageReviewTab: View {
    let records: [SwingRecord]
    @Binding var selectedRecordKey: String?

    private var selectedRecord: SwingRecord? {
        if let selectedRecordKey {
            return records.first(where: { garageRecordSelectionKey(for: $0) == selectedRecordKey }) ?? records.first
        }

        return records.first
    }

    var body: some View {
        ModuleActivityFeedSection(title: "Checkpoint Review") {
            if let selectedRecord {
                VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
                    HStack(alignment: .center, spacing: ModuleSpacing.medium) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Swing")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppModule.garage.theme.textMuted)

                            Menu {
                                ForEach(records) { record in
                                    Button(record.title) {
                                        selectedRecordKey = garageRecordSelectionKey(for: record)
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(selectedRecord.title)
                                        .font(.title3.weight(.bold))
                                        .lineLimit(1)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundStyle(AppModule.garage.theme.textPrimary)
                            }
                            .menuStyle(.borderlessButton)
                        }

                        Spacer(minLength: 0)
                    }

                    GarageFocusedReviewWorkspace(record: selectedRecord)
                }
            } else {
                ModuleEmptyStateCard(
                    theme: AppModule.garage.theme,
                    title: "Review workflow is ready",
                    message: "Import a swing video from Overview or Records to begin checkpoint review.",
                    actionTitle: "Go To Records",
                    action: {}
                )
            }
        }
        .onAppear(perform: syncSelection)
        .onChange(of: records.map(garageRecordSelectionKey)) { _, _ in
            syncSelection()
        }
    }

    private func syncSelection() {
        guard records.isEmpty == false else {
            selectedRecordKey = nil
            return
        }

        if let selectedRecordKey,
           records.contains(where: { garageRecordSelectionKey(for: $0) == selectedRecordKey }) {
            return
        }

        selectedRecordKey = records.first.map(garageRecordSelectionKey)
    }
}

private struct GarageManualAnchorDraft: Equatable {
    let frameIndex: Int
    var point: CGPoint
}

private enum GarageOverlayPresentationMode {
    case anchorOnly
    case diagnosticPose
}

private func garageAspectFitRect(contentSize: CGSize, in container: CGRect) -> CGRect {
    guard contentSize.width > 0, contentSize.height > 0, container.width > 0, container.height > 0 else {
        return .zero
    }

    let scale = min(container.width / contentSize.width, container.height / contentSize.height)
    let scaledSize = CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
    let origin = CGPoint(
        x: container.midX - (scaledSize.width / 2),
        y: container.midY - (scaledSize.height / 2)
    )
    return CGRect(origin: origin, size: scaledSize)
}

private func garageMappedPoint(x: Double, y: Double, in rect: CGRect) -> CGPoint {
    CGPoint(
        x: rect.minX + (rect.width * x),
        y: rect.minY + (rect.height * y)
    )
}

private func garageMappedPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
    garageMappedPoint(x: point.x, y: point.y, in: rect)
}

private func garageNormalizedPoint(from location: CGPoint, in rect: CGRect) -> CGPoint? {
    guard rect.contains(location), rect.width > 0, rect.height > 0 else {
        return nil
    }

    let normalizedX = min(max((location.x - rect.minX) / rect.width, 0), 1)
    let normalizedY = min(max((location.y - rect.minY) / rect.height, 0), 1)
    return CGPoint(x: normalizedX, y: normalizedY)
}

private func garageClampedNormalizedPoint(_ point: CGPoint) -> CGPoint {
    CGPoint(
        x: min(max(point.x, 0), 1),
        y: min(max(point.y, 0), 1)
    )
}

private struct GarageFocusedReviewWorkspace: View {
    @Environment(\.modelContext) private var modelContext

    let record: SwingRecord

    @State private var currentTime = 0.0
    @State private var reviewImage: CGImage?
    @State private var isLoadingFrame = false
    @State private var assetDuration = 0.0
    @State private var selectedPhase: SwingPhase = .address
    @State private var isShowingCompletionPlayback = false
    @State private var didAutoPresentCompletionPlayback = false
    @State private var isEditingAnchor = false
    @State private var manualAnchorDraft: GarageManualAnchorDraft?
    @State private var overlayPresentationMode: GarageOverlayPresentationMode = .anchorOnly

    private var resolvedReviewVideo: GarageResolvedReviewVideo? {
        GarageMediaStore.resolvedReviewVideo(for: record)
    }

    private var reviewVideoURL: URL? {
        resolvedReviewVideo?.url
    }

    private var reviewFrameSource: GarageReviewFrameSourceState {
        GarageMediaStore.reviewFrameSource(for: record)
    }

    private var orderedKeyframes: [GarageTimelineMarker] {
        record.keyFrames
            .sorted { lhs, rhs in
                (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
            }
            .compactMap { keyFrame in
                guard record.swingFrames.indices.contains(keyFrame.frameIndex) else {
                    return nil
                }

                return GarageTimelineMarker(
                    keyFrame: keyFrame,
                    timestamp: record.swingFrames[keyFrame.frameIndex].timestamp
                )
            }
    }

    private var selectedMarker: GarageTimelineMarker? {
        orderedKeyframes.first(where: { $0.keyFrame.phase == selectedPhase })
    }

    private var selectedKeyFrame: KeyFrame? {
        record.keyFrames.first(where: { $0.phase == selectedPhase })
    }

    private var selectedCheckpointStatus: KeyframeValidationStatus {
        selectedKeyFrame?.reviewStatus ?? .pending
    }

    private var selectedAnchor: HandAnchor? {
        record.handAnchors.first(where: { $0.phase == selectedPhase })
    }

    private var displayedAnchor: HandAnchor? {
        if let manualAnchorDraft {
            return HandAnchor(
                phase: selectedPhase,
                x: manualAnchorDraft.point.x,
                y: manualAnchorDraft.point.y,
                source: .manual
            )
        }

        return selectedAnchor
    }

    private var currentFrameIndex: Int? {
        guard record.swingFrames.isEmpty == false else {
            return nil
        }

        return record.swingFrames.enumerated().min { lhs, rhs in
            abs(lhs.element.timestamp - currentTime) < abs(rhs.element.timestamp - currentTime)
        }?.offset
    }

    private var currentFrame: SwingFrame? {
        guard let currentFrameIndex, record.swingFrames.indices.contains(currentFrameIndex) else {
            return nil
        }

        return record.swingFrames[currentFrameIndex]
    }

    private var effectiveDuration: Double {
        max(record.swingFrames.map(\.timestamp).max() ?? 0, assetDuration, 0.1)
    }

    private var frameRequestID: String {
        [
            garageRecordSelectionKey(for: record),
            reviewVideoURL?.absoluteString ?? "no-video",
            String(format: "%.4f", currentTime)
        ].joined(separator: "::")
    }

    private var fullHandPathSamples: [GarageHandPathSample] {
        garageHandPathSamples(from: record.swingFrames)
    }

    private var reviewRecoveryTitle: String {
        switch reviewFrameSource {
        case .video:
            "Stored video recovered"
        case .poseFallback:
            "Pose fallback active"
        case .recoveryNeeded:
            "Review media needs recovery"
        }
    }

    private var reviewRecoveryBody: String {
        switch reviewFrameSource {
        case .video:
            if let origin = resolvedReviewVideo?.origin {
                return "Garage is rendering this checkpoint from the recovered \(origin.rawValue.replacingOccurrences(of: "Storage", with: " storage").replacingOccurrences(of: "Bookmark", with: " bookmark")) source."
            }
            return "Garage found a stored review video for this checkpoint."
        case .poseFallback:
            return "Stored footage is missing, so Garage is showing sampled pose data instead. Re-import this swing if you need the original video visuals."
        case .recoveryNeeded:
            return "Neither stored footage nor fallback-ready pose frames are available yet. Re-import this swing to restore full checkpoint review."
        }
    }

    var body: some View {
        ModuleRowSurface(theme: AppModule.garage.theme) {
            GarageFocusedReviewFrame(
                source: reviewFrameSource,
                image: reviewImage,
                isLoadingFrame: isLoadingFrame,
                currentFrame: currentFrame,
                selectedAnchor: displayedAnchor,
                highlightedStatus: selectedCheckpointStatus,
                isEditingAnchor: isEditingAnchor,
                overlayMode: overlayPresentationMode,
                onSetAnchor: updateDraftAnchor
            )

            VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedPhase.reviewTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppModule.garage.theme.textPrimary)

                        HStack(spacing: 8) {
                            GarageCheckpointStatusBadge(status: selectedCheckpointStatus)

                            if selectedKeyFrame?.source == .adjusted {
                                Label("Frame adjusted", systemImage: "timeline.selection")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }

                            if displayedAnchor?.source == .manual {
                                Label("Manual anchor", systemImage: "hand.draw.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    GarageCheckpointProgressSummary(record: record)
                }

                GarageCheckpointProgressStrip(
                    selectedPhase: selectedPhase,
                    markers: orderedKeyframes,
                    statusProvider: { record.reviewStatus(for: $0) }
                ) { phase in
                    cancelAnchorEditing()
                    selectedPhase = phase
                    seekToSelectedCheckpoint()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(isEditingAnchor ? "Scrub to the exact frame, then drag the hand marker into place." : "Scrub to pinpoint the checkpoint frame.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppModule.garage.theme.textSecondary)

                        Spacer(minLength: 0)

                        if let currentFrameIndex {
                            Text("Frame \(currentFrameIndex + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppModule.garage.theme.textPrimary)
                        }
                    }

                    GarageTimelineScrubber(
                        range: 0...effectiveDuration,
                        currentTime: $currentTime,
                        markers: orderedKeyframes,
                        selectedPhase: selectedPhase,
                        statusProvider: { record.reviewStatus(for: $0) }
                    )
                }

                GarageReviewToolRail(
                    selectedStatus: selectedCheckpointStatus,
                    isEditingAnchor: isEditingAnchor,
                    canAdjustCurrentFrame: currentFrameIndex != nil,
                    canMoveBetweenCheckpoints: orderedKeyframes.isEmpty == false,
                    onPrevious: previousCheckpoint,
                    onBeginAdjust: beginAnchorEditing,
                    onCancelAdjust: cancelAnchorEditing,
                    onSaveAdjust: saveAnchorAdjustment,
                    onApprove: approveCheckpoint,
                    onFlag: flagCheckpoint,
                    onNext: nextCheckpoint
                )

                if reviewFrameSource != .video {
                    GarageReviewRecoveryCallout(
                        title: reviewRecoveryTitle,
                        message: reviewRecoveryBody,
                        state: reviewFrameSource
                    )
                }

                if record.allCheckpointsApproved, let reviewVideoURL {
                    GarageCompletionPlaybackCallout {
                        isShowingCompletionPlayback = true
                    }
                    .sheet(isPresented: $isShowingCompletionPlayback) {
                        GarageSlowMotionPlaybackSheet(
                            videoURL: reviewVideoURL,
                            pathSamples: fullHandPathSamples
                        )
                    }
                }
            }
        }
        .task(id: garageRecordSelectionKey(for: record)) {
            record.hydrateCheckpointStatusesFromAggregateIfNeeded()
            record.refreshKeyframeValidationStatus()
            try? modelContext.save()
            syncSelectedPhase()
            seekToSelectedCheckpoint()
            await loadAssetDuration()
            autoPresentCompletionPlaybackIfNeeded()
        }
        .task(id: frameRequestID) {
            await loadFrameImage()
        }
        .onChange(of: currentFrameIndex) { _, _ in
            syncDraftAnchorWithCurrentFrame()
        }
    }

    private func loadAssetDuration() async {
        guard let reviewVideoURL else {
            await MainActor.run {
                assetDuration = record.swingFrames.map(\.timestamp).max() ?? 0
            }
            return
        }

        let metadata = await GarageMediaStore.assetMetadata(for: reviewVideoURL)
        await MainActor.run {
            assetDuration = metadata?.duration ?? (record.swingFrames.map(\.timestamp).max() ?? 0)
        }
    }

    private func loadFrameImage() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        guard Task.isCancelled == false else {
            return
        }

        guard let reviewVideoURL else {
            await MainActor.run {
                reviewImage = nil
                isLoadingFrame = false
            }
            return
        }

        await MainActor.run {
            isLoadingFrame = true
        }

        guard Task.isCancelled == false else {
            await MainActor.run {
                isLoadingFrame = false
            }
            return
        }

        let image = await GarageMediaStore.thumbnail(
            for: reviewVideoURL,
            at: currentTime,
            maximumSize: CGSize(width: 1600, height: 1600)
        )

        await MainActor.run {
            reviewImage = image
            isLoadingFrame = false
        }
    }

    private func syncSelectedPhase() {
        if orderedKeyframes.contains(where: { $0.keyFrame.phase == selectedPhase }) {
            return
        }

        selectedPhase = orderedKeyframes.first?.keyFrame.phase ?? .address
    }

    private func seekToSelectedCheckpoint() {
        if let selectedMarker {
            currentTime = selectedMarker.timestamp
        } else if let firstTimestamp = record.swingFrames.first?.timestamp {
            currentTime = firstTimestamp
        } else {
            currentTime = 0
        }
    }

    private func previousCheckpoint() {
        cancelAnchorEditing()
        moveCheckpointSelection(by: -1)
    }

    private func nextCheckpoint() {
        cancelAnchorEditing()
        moveCheckpointSelection(by: 1)
    }

    private func moveCheckpointSelection(by offset: Int) {
        guard orderedKeyframes.isEmpty == false else { return }
        let currentIndex = orderedKeyframes.firstIndex(where: { $0.keyFrame.phase == selectedPhase }) ?? 0
        let targetIndex = min(max(currentIndex + offset, 0), orderedKeyframes.count - 1)
        selectedPhase = orderedKeyframes[targetIndex].keyFrame.phase
        seekToSelectedCheckpoint()
    }

    private func approveCheckpoint() {
        cancelAnchorEditing()
        guard let keyframeIndex = record.keyFrames.firstIndex(where: { $0.phase == selectedPhase }) else { return }
        record.keyFrames[keyframeIndex].reviewStatus = .approved
        record.refreshKeyframeValidationStatus()
        try? modelContext.save()
        autoPresentCompletionPlaybackIfNeeded()
    }

    private func flagCheckpoint() {
        cancelAnchorEditing()
        guard let keyframeIndex = record.keyFrames.firstIndex(where: { $0.phase == selectedPhase }) else { return }
        record.keyFrames[keyframeIndex].reviewStatus = .flagged
        record.refreshKeyframeValidationStatus()
        try? modelContext.save()
        didAutoPresentCompletionPlayback = false
    }

    private func beginAnchorEditing() {
        guard currentFrameIndex != nil else { return }
        isEditingAnchor = true
        syncDraftAnchorWithCurrentFrame()
    }

    private func cancelAnchorEditing() {
        isEditingAnchor = false
        manualAnchorDraft = nil
    }

    private func syncDraftAnchorWithCurrentFrame() {
        guard isEditingAnchor, let currentFrameIndex, let currentFrame else {
            return
        }

        let initialPoint: CGPoint
        if selectedKeyFrame?.frameIndex == currentFrameIndex, let selectedAnchor {
            initialPoint = CGPoint(x: selectedAnchor.x, y: selectedAnchor.y)
        } else {
            initialPoint = GarageAnalysisPipeline.handCenter(in: currentFrame)
        }

        manualAnchorDraft = GarageManualAnchorDraft(
            frameIndex: currentFrameIndex,
            point: garageClampedNormalizedPoint(initialPoint)
        )
    }

    private func updateDraftAnchor(_ point: CGPoint) {
        guard isEditingAnchor, let currentFrameIndex else {
            return
        }

        manualAnchorDraft = GarageManualAnchorDraft(
            frameIndex: currentFrameIndex,
            point: garageClampedNormalizedPoint(point)
        )
    }

    private func saveAnchorAdjustment() {
        guard let manualAnchorDraft else { return }

        if let keyframeIndex = record.keyFrames.firstIndex(where: { $0.phase == selectedPhase }) {
            record.keyFrames[keyframeIndex].frameIndex = manualAnchorDraft.frameIndex
            record.keyFrames[keyframeIndex].source = .adjusted
            record.keyFrames[keyframeIndex].reviewStatus = .pending
        } else {
            record.keyFrames.append(
                KeyFrame(
                    phase: selectedPhase,
                    frameIndex: manualAnchorDraft.frameIndex,
                    source: .adjusted,
                    reviewStatus: .pending
                )
            )
        }

        record.keyFrames.sort { lhs, rhs in
            (SwingPhase.allCases.firstIndex(of: lhs.phase) ?? 0) < (SwingPhase.allCases.firstIndex(of: rhs.phase) ?? 0)
        }

        var mergedAnchors = GarageAnalysisPipeline.mergedHandAnchors(
            preserving: record.handAnchors,
            from: record.swingFrames,
            keyFrames: record.keyFrames
        )
        mergedAnchors = GarageAnalysisPipeline.upsertingHandAnchor(
            HandAnchor(
                phase: selectedPhase,
                x: manualAnchorDraft.point.x,
                y: manualAnchorDraft.point.y,
                source: .manual
            ),
            into: mergedAnchors
        )

        record.handAnchors = mergedAnchors
        record.pathPoints = GarageAnalysisPipeline.generatePathPoints(from: record.handAnchors, samplesPerSegment: 16)
        record.refreshKeyframeValidationStatus()
        try? modelContext.save()
        didAutoPresentCompletionPlayback = false
        cancelAnchorEditing()
        seekToSelectedCheckpoint()
    }

    private func autoPresentCompletionPlaybackIfNeeded() {
        guard record.allCheckpointsApproved, didAutoPresentCompletionPlayback == false, reviewVideoURL != nil else { return }
        didAutoPresentCompletionPlayback = true
        isShowingCompletionPlayback = true
    }
}

private struct GarageFocusedReviewFrame: View {
    let source: GarageReviewFrameSourceState
    let image: CGImage?
    let isLoadingFrame: Bool
    let currentFrame: SwingFrame?
    let selectedAnchor: HandAnchor?
    let highlightedStatus: KeyframeValidationStatus
    let isEditingAnchor: Bool
    let overlayMode: GarageOverlayPresentationMode
    let onSetAnchor: (CGPoint) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppModule.garage.theme.surfaceSecondary,
                            AppModule.garage.theme.surfaceSecondary.opacity(0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image {
                GarageReviewImageOverlay(
                    image: image,
                    currentFrame: currentFrame,
                    selectedAnchor: selectedAnchor,
                    highlightedStatus: highlightedStatus,
                    isEditingAnchor: isEditingAnchor,
                    overlayMode: overlayMode,
                    onSetAnchor: onSetAnchor
                )
                .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
            } else if let currentFrame {
                GaragePoseFallbackOverlay(
                    currentFrame: currentFrame,
                    selectedAnchor: selectedAnchor,
                    highlightedStatus: highlightedStatus,
                    isEditingAnchor: isEditingAnchor,
                    overlayMode: overlayMode,
                    onSetAnchor: onSetAnchor
                )
                .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
            } else {
                VStack(spacing: ModuleSpacing.small) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppModule.garage.theme.textMuted)
                    Text("Review frame unavailable")
                        .font(.headline)
                        .foregroundStyle(AppModule.garage.theme.textPrimary)
                    Text("Re-import the swing to restore video review for this checkpoint.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }
                .padding()
            }

            if source != .recoveryNeeded {
                Text(source == .poseFallback ? "Pose Fallback" : "Video Review")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(source == .poseFallback ? .orange : AppModule.garage.theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(14)
            }

            if isLoadingFrame {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppModule.garage.theme.primary)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
            }
        }
        .frame(minHeight: 560)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
        )
    }
}

private struct GarageReviewImageOverlay: View {
    let image: CGImage
    let currentFrame: SwingFrame?
    let selectedAnchor: HandAnchor?
    let highlightedStatus: KeyframeValidationStatus
    let isEditingAnchor: Bool
    let overlayMode: GarageOverlayPresentationMode
    let onSetAnchor: (CGPoint) -> Void

    var body: some View {
        GeometryReader { proxy in
            let containerRect = CGRect(origin: .zero, size: proxy.size)
            let imageRect = garageAspectFitRect(
                contentSize: CGSize(width: image.width, height: image.height),
                in: containerRect
            )

            ZStack {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                GarageReviewFrameOverlayCanvas(
                    drawRect: imageRect,
                    currentFrame: currentFrame,
                    selectedAnchor: selectedAnchor,
                    highlightedStatus: highlightedStatus,
                    isEditingAnchor: isEditingAnchor,
                    overlayMode: overlayMode
                )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEditingAnchor, let point = garageNormalizedPoint(from: value.location, in: imageRect) else {
                            return
                        }
                        onSetAnchor(point)
                    }
            )
        }
    }
}

private struct GaragePoseFallbackOverlay: View {
    let currentFrame: SwingFrame
    let selectedAnchor: HandAnchor?
    let highlightedStatus: KeyframeValidationStatus
    let isEditingAnchor: Bool
    let overlayMode: GarageOverlayPresentationMode
    let onSetAnchor: (CGPoint) -> Void

    var body: some View {
        GeometryReader { proxy in
            let containerRect = CGRect(origin: .zero, size: proxy.size)

            ZStack {
                LinearGradient(
                    colors: [
                        AppModule.garage.theme.primary.opacity(0.18),
                        AppModule.garage.theme.surfaceSecondary.opacity(0.85),
                        Color.black.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Canvas { context, _ in
                    let insetRect = containerRect.insetBy(dx: 24, dy: 24)

                    let glowRect = insetRect.insetBy(dx: insetRect.width * 0.22, dy: insetRect.height * 0.14)
                    context.fill(
                        Ellipse().path(in: glowRect),
                        with: .radialGradient(
                            Gradient(colors: [AppModule.garage.theme.primary.opacity(0.22), .clear]),
                            center: CGPoint(x: glowRect.midX, y: glowRect.midY),
                            startRadius: 4,
                            endRadius: max(glowRect.width, glowRect.height) * 0.55
                        )
                    )
                }

                GarageReviewFrameOverlayCanvas(
                    drawRect: containerRect.insetBy(dx: 20, dy: 20),
                    currentFrame: currentFrame,
                    selectedAnchor: selectedAnchor,
                    highlightedStatus: highlightedStatus,
                    isEditingAnchor: isEditingAnchor,
                    overlayMode: overlayMode
                )

                VStack(spacing: 6) {
                    Image(systemName: "figure.golf")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textPrimary.opacity(0.82))
                    Text("Sampled pose reconstruction")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textSecondary)
                }
                .padding(.top, 18)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEditingAnchor, let point = garageNormalizedPoint(from: value.location, in: containerRect.insetBy(dx: 20, dy: 20)) else {
                            return
                        }
                        onSetAnchor(point)
                    }
            )
        }
    }
}

private struct GarageReviewFrameOverlayCanvas: View {
    let drawRect: CGRect
    let currentFrame: SwingFrame?
    let selectedAnchor: HandAnchor?
    let highlightedStatus: KeyframeValidationStatus
    let isEditingAnchor: Bool
    let overlayMode: GarageOverlayPresentationMode

    var body: some View {
        Canvas { context, _ in
            guard drawRect.isEmpty == false else {
                return
            }

            if let currentFrame, overlayMode == .diagnosticPose {
                let skeletonSegments: [(SwingJointName, SwingJointName)] = [
                    (.leftShoulder, .rightShoulder),
                    (.leftShoulder, .leftElbow),
                    (.leftElbow, .leftWrist),
                    (.rightShoulder, .rightElbow),
                    (.rightElbow, .rightWrist),
                    (.leftShoulder, .leftHip),
                    (.rightShoulder, .rightHip),
                    (.leftHip, .rightHip)
                ]

                for segment in skeletonSegments {
                    guard
                        let start = currentFrame.availablePoint(named: segment.0),
                        let end = currentFrame.availablePoint(named: segment.1)
                    else {
                        continue
                    }

                    var path = Path()
                    path.move(to: garageMappedPoint(start, in: drawRect))
                    path.addLine(to: garageMappedPoint(end, in: drawRect))
                    context.stroke(path, with: .color(Color.white.opacity(0.22)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                }

                let leftWrist = garageMappedPoint(currentFrame.point(named: .leftWrist), in: drawRect)
                let rightWrist = garageMappedPoint(currentFrame.point(named: .rightWrist), in: drawRect)
                let handCenter = CGPoint(x: (leftWrist.x + rightWrist.x) / 2, y: (leftWrist.y + rightWrist.y) / 2)

                var wristLine = Path()
                wristLine.move(to: leftWrist)
                wristLine.addLine(to: rightWrist)
                context.stroke(wristLine, with: .color(.cyan.opacity(0.92)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

                for point in [leftWrist, rightWrist] {
                    let rect = CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9)
                    context.fill(Ellipse().path(in: rect), with: .color(.cyan))
                }

                let autoCenterRect = CGRect(x: handCenter.x - 6, y: handCenter.y - 6, width: 12, height: 12)
                context.fill(Ellipse().path(in: autoCenterRect), with: .color(Color.white.opacity(0.72)))
            }

            if let selectedAnchor {
                let anchorPoint = garageMappedPoint(x: selectedAnchor.x, y: selectedAnchor.y, in: drawRect)
                let outerRect = CGRect(x: anchorPoint.x - 11, y: anchorPoint.y - 11, width: 22, height: 22)
                let innerRect = CGRect(x: anchorPoint.x - 6, y: anchorPoint.y - 6, width: 12, height: 12)
                context.fill(Ellipse().path(in: outerRect), with: .color(highlightedStatus.reviewTint.opacity(0.24)))
                context.stroke(Ellipse().path(in: outerRect), with: .color(highlightedStatus.reviewTint), lineWidth: isEditingAnchor ? 2.4 : 1.6)
                context.fill(Ellipse().path(in: innerRect), with: .color(highlightedStatus.reviewTint))

                if isEditingAnchor {
                    var horizontalGuide = Path()
                    horizontalGuide.move(to: CGPoint(x: drawRect.minX, y: anchorPoint.y))
                    horizontalGuide.addLine(to: CGPoint(x: drawRect.maxX, y: anchorPoint.y))
                    context.stroke(horizontalGuide, with: .color(highlightedStatus.reviewTint.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))

                    var verticalGuide = Path()
                    verticalGuide.move(to: CGPoint(x: anchorPoint.x, y: drawRect.minY))
                    verticalGuide.addLine(to: CGPoint(x: anchorPoint.x, y: drawRect.maxY))
                    context.stroke(verticalGuide, with: .color(highlightedStatus.reviewTint.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                }
            }
        }
    }
}

private extension SwingFrame {
    func availablePoint(named name: SwingJointName) -> CGPoint? {
        guard let joint = joints.first(where: { $0.name == name }) else {
            return nil
        }

        return CGPoint(x: joint.x, y: joint.y)
    }
}

private struct GarageCheckpointProgressStrip: View {
    let selectedPhase: SwingPhase
    let markers: [GarageTimelineMarker]
    let statusProvider: (SwingPhase) -> KeyframeValidationStatus
    let onSelect: (SwingPhase) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ModuleSpacing.small) {
                ForEach(SwingPhase.allCases) { phase in
                    let marker = markers.first(where: { $0.keyFrame.phase == phase })
                    let status = statusProvider(phase)
                    Button {
                        onSelect(phase)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(status.reviewTint)
                                .frame(width: 8, height: 8)

                            Text(shortTitle(for: phase))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppModule.garage.theme.textPrimary)

                            if marker?.keyFrame.source == .adjusted {
                                Image(systemName: "hand.draw")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedPhase == phase
                                ? AppModule.garage.theme.primary.opacity(0.14)
                                : AppModule.garage.theme.surfaceSecondary,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedPhase == phase ? AppModule.garage.theme.primary : status.reviewTint.opacity(status == .pending ? 0.2 : 0.45), lineWidth: selectedPhase == phase ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(phase.reviewTitle)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func shortTitle(for phase: SwingPhase) -> String {
        switch phase {
        case .address:
            "Setup"
        case .takeaway:
            "Take"
        case .shaftParallel:
            "Shaft"
        case .topOfBackswing:
            "Top"
        case .transition:
            "Transition"
        case .earlyDownswing:
            "Down"
        case .impact:
            "Impact"
        case .followThrough:
            "Finish"
        }
    }
}

private struct GarageTimelineScrubber: View {
    let range: ClosedRange<Double>
    @Binding var currentTime: Double
    let markers: [GarageTimelineMarker]
    let selectedPhase: SwingPhase
    let statusProvider: (SwingPhase) -> KeyframeValidationStatus

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(proxy.size.width, 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppModule.garage.theme.surfaceSecondary)

                Capsule()
                    .fill(AppModule.garage.theme.primary.opacity(0.18))
                    .frame(width: indicatorX(in: trackWidth))

                ForEach(markers) { marker in
                    if range.contains(marker.timestamp) {
                        let markerStatus = statusProvider(marker.keyFrame.phase)
                        Circle()
                            .fill(marker.keyFrame.phase == selectedPhase ? markerStatus.reviewTint : Color.white)
                            .frame(width: marker.keyFrame.phase == selectedPhase ? 12 : 8, height: marker.keyFrame.phase == selectedPhase ? 12 : 8)
                            .overlay(
                                Circle()
                                    .stroke(marker.keyFrame.source == .adjusted ? Color.orange : markerStatus.reviewTint, lineWidth: 1.5)
                            )
                            .offset(x: max(0, markerX(for: marker.timestamp, in: trackWidth) - (marker.keyFrame.phase == selectedPhase ? 6 : 4)))
                    }
                }

                Circle()
                    .fill(AppModule.garage.theme.primary)
                    .frame(width: 18, height: 18)
                    .offset(x: max(0, indicatorX(in: trackWidth) - 9))
            }
            .frame(height: 32)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = min(max(value.location.x / trackWidth, 0), 1)
                        let span = range.upperBound - range.lowerBound
                        currentTime = range.lowerBound + (span * progress)
                    }
            )
        }
        .frame(height: 32)
    }

    private func markerX(for timestamp: Double, in width: CGFloat) -> CGFloat {
        let span = max(range.upperBound - range.lowerBound, 0.0001)
        let progress = (timestamp - range.lowerBound) / span
        return width * min(max(progress, 0), 1)
    }

    private func indicatorX(in width: CGFloat) -> CGFloat {
        markerX(for: currentTime, in: width)
    }
}

private struct GarageCheckpointStatusBadge: View {
    let status: KeyframeValidationStatus

    var body: some View {
        Label(status.title, systemImage: iconName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(status.reviewTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.reviewBackground, in: Capsule())
    }

    private var iconName: String {
        switch status {
        case .pending:
            "clock"
        case .approved:
            "checkmark.circle.fill"
        case .flagged:
            "flag.fill"
        }
    }
}

private struct GarageCheckpointProgressSummary: View {
    let record: SwingRecord

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("\(record.approvedCheckpointCount) of \(SwingPhase.allCases.count) approved")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppModule.garage.theme.textPrimary)

            HStack(spacing: 6) {
                summaryPill(title: "Approved", value: record.approvedCheckpointCount, tint: .green)
                summaryPill(title: "Flagged", value: record.flaggedCheckpointCount, tint: .red)
                summaryPill(title: "Pending", value: record.pendingCheckpointCount, tint: AppModule.garage.theme.primary)
            }
        }
    }

    private func summaryPill(title: String, value: Int, tint: Color) -> some View {
        Text("\(title) \(value)")
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct GarageReviewToolRail: View {
    let selectedStatus: KeyframeValidationStatus
    let isEditingAnchor: Bool
    let canAdjustCurrentFrame: Bool
    let canMoveBetweenCheckpoints: Bool
    let onPrevious: () -> Void
    let onBeginAdjust: () -> Void
    let onCancelAdjust: () -> Void
    let onSaveAdjust: () -> Void
    let onApprove: () -> Void
    let onFlag: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                iconButton(
                    systemImage: "chevron.left",
                    tint: AppModule.garage.theme.textPrimary,
                    filled: false,
                    disabled: canMoveBetweenCheckpoints == false,
                    action: onPrevious
                )
                iconButton(
                    systemImage: "chevron.right",
                    tint: AppModule.garage.theme.textPrimary,
                    filled: false,
                    disabled: canMoveBetweenCheckpoints == false,
                    action: onNext
                )
            }
            .padding(4)
            .background(AppModule.garage.theme.surfaceSecondary, in: Capsule())

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if isEditingAnchor {
                    iconButton(
                        systemImage: "xmark",
                        tint: AppModule.garage.theme.textSecondary,
                        filled: false,
                        disabled: false,
                        action: onCancelAdjust
                    )
                }

                Button(action: isEditingAnchor ? onSaveAdjust : onBeginAdjust) {
                    HStack(spacing: 8) {
                        Image(systemName: isEditingAnchor ? "checkmark.circle.fill" : "hand.point.up.left.fill")
                        Text(isEditingAnchor ? "Save Anchor" : "Adjust")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isEditingAnchor ? Color.white : AppModule.garage.theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(isEditingAnchor ? AppModule.garage.theme.primary : AppModule.garage.theme.surfaceSecondary.opacity(0.95))
                    )
                    .overlay(
                        Capsule()
                            .stroke(AppModule.garage.theme.borderStrong.opacity(isEditingAnchor ? 0 : 0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(canAdjustCurrentFrame == false)
                .opacity(canAdjustCurrentFrame ? 1 : 0.45)
                .accessibilityLabel(isEditingAnchor ? "Save manual hand anchor" : "Adjust keyframe and hand anchor")
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                iconButton(
                    systemImage: "checkmark.circle.fill",
                    tint: .green,
                    filled: selectedStatus == .approved,
                    disabled: false,
                    action: onApprove
                )
                .accessibilityLabel("Approve checkpoint")

                iconButton(
                    systemImage: "flag.fill",
                    tint: .red,
                    filled: selectedStatus == .flagged,
                    disabled: false,
                    action: onFlag
                )
                .accessibilityLabel("Flag checkpoint")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
        )
    }

    private func iconButton(
        systemImage: String,
        tint: Color,
        filled: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(filled ? Color.white : tint)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(filled ? tint : tint.opacity(0.12))
                )
                .overlay(
                    Circle()
                        .stroke(tint.opacity(filled ? 0 : 0.28), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

private struct GarageReviewRecoveryCallout: View {
    let title: String
    let message: String
    let state: GarageReviewFrameSourceState

    var body: some View {
        HStack(alignment: .top, spacing: ModuleSpacing.medium) {
            Image(systemName: iconName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(iconTint)
                .frame(width: 34, height: 34)
                .background(iconTint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(AppModule.garage.theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous)
                .stroke(iconTint.opacity(0.24), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch state {
        case .video:
            "play.rectangle.fill"
        case .poseFallback:
            "figure.golf"
        case .recoveryNeeded:
            "arrow.triangle.2.circlepath.circle"
        }
    }

    private var iconTint: Color {
        switch state {
        case .video:
            AppModule.garage.theme.primary
        case .poseFallback:
            .orange
        case .recoveryNeeded:
            .red
        }
    }
}

private struct GarageCompletionPlaybackCallout: View {
    let replay: () -> Void

    var body: some View {
        HStack(spacing: ModuleSpacing.medium) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Review approved")
                    .font(.headline)
                    .foregroundStyle(AppModule.garage.theme.textPrimary)
                Text("Open the slow-motion hand-path playback for a clean final pass.")
                    .font(.subheadline)
                    .foregroundStyle(AppModule.garage.theme.textSecondary)
            }

            Spacer(minLength: 0)

            Button("Play Slow Motion", action: replay)
                .buttonStyle(.borderedProminent)
                .tint(AppModule.garage.theme.primary)
        }
        .padding()
        .background(AppModule.garage.theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct GarageReviewStatusPill: View {
    let status: KeyframeValidationStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(status.reviewTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.reviewBackground, in: Capsule())
    }
}

private struct GarageSlowMotionPlaybackSheet: View {
    @Environment(\.dismiss) private var dismiss

    let videoURL: URL
    let pathSamples: [GarageHandPathSample]

    @StateObject private var playbackController: GarageSlowMotionPlaybackController
    @State private var videoDisplaySize = CGSize(width: 1, height: 1)

    init(videoURL: URL, pathSamples: [GarageHandPathSample]) {
        self.videoURL = videoURL
        self.pathSamples = pathSamples
        _playbackController = StateObject(wrappedValue: GarageSlowMotionPlaybackController(url: videoURL))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
                Text("Slow-motion review")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppModule.garage.theme.textPrimary)

                Text("A clean replay of the approved swing with the hand path drawn progressively across the full motion.")
                    .foregroundStyle(AppModule.garage.theme.textSecondary)

                ZStack {
                    GarageSlowMotionPlayerView(player: playbackController.player)
                        .frame(minHeight: 480)
                        .clipShape(RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))

                    GarageSlowMotionPathOverlay(
                        pathSamples: pathSamples,
                        currentTime: playbackController.currentTime,
                        videoSize: videoDisplaySize
                    )
                    .allowsHitTesting(false)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                        .stroke(AppModule.garage.theme.borderSubtle, lineWidth: 1)
                )

                HStack(spacing: ModuleSpacing.medium) {
                    Text("Playback \(String(format: "%.2fs", playbackController.currentTime))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppModule.garage.theme.textSecondary)

                    Spacer(minLength: 0)

                    Button("Replay") {
                        playbackController.replay()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppModule.garage.theme.primary)
                }
            }
            .padding(ModuleSpacing.large)
            .navigationTitle("Approved Playback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            let metadata = await GarageMediaStore.assetMetadata(for: videoURL)
            await MainActor.run {
                videoDisplaySize = metadata?.naturalSize ?? CGSize(width: 1, height: 1)
            }
        }
        .onAppear {
            playbackController.startSlowMotion()
        }
        .onDisappear {
            playbackController.stop()
        }
    }
}

private struct GarageSlowMotionPathOverlay: View {
    let pathSamples: [GarageHandPathSample]
    let currentTime: Double
    let videoSize: CGSize

    private var visibleSamples: [GarageHandPathSample] {
        pathSamples.filter { $0.timestamp <= currentTime + 0.0001 }
    }

    var body: some View {
        GeometryReader { proxy in
            let containerRect = CGRect(origin: .zero, size: proxy.size)
            let videoRect = aspectFitRect(videoSize: videoSize, in: containerRect)

            Canvas { context, _ in
                guard videoRect.isEmpty == false, visibleSamples.count >= 2 else {
                    return
                }

                let maxSpeed = max(visibleSamples.map(\.speed).max() ?? 0.001, 0.001)
                for segmentIndex in 1..<visibleSamples.count {
                    let previous = visibleSamples[segmentIndex - 1]
                    let current = visibleSamples[segmentIndex]
                    let normalizedSpeed = min(max(current.speed / maxSpeed, 0), 1)
                    let baseWidth = 2.4 + (normalizedSpeed * 2.2)

                    var segmentPath = Path()
                    segmentPath.move(to: mappedPoint(x: previous.x, y: previous.y, in: videoRect))
                    segmentPath.addLine(to: mappedPoint(x: current.x, y: current.y, in: videoRect))

                    context.stroke(
                        segmentPath,
                        with: .color(Color.white.opacity(0.78)),
                        style: StrokeStyle(lineWidth: baseWidth + 2.0, lineCap: .round, lineJoin: .round)
                    )
                    context.stroke(
                        segmentPath,
                        with: .color(AppModule.garage.theme.primary.opacity(0.45 + (normalizedSpeed * 0.45))),
                        style: StrokeStyle(lineWidth: baseWidth, lineCap: .round, lineJoin: .round)
                    )
                }

                if let lastSample = visibleSamples.last {
                    let point = mappedPoint(x: lastSample.x, y: lastSample.y, in: videoRect)
                    let outerRect = CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)
                    let innerRect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                    context.fill(Ellipse().path(in: outerRect), with: .color(Color.white))
                    context.fill(Ellipse().path(in: innerRect), with: .color(AppModule.garage.theme.primary))
                }
            }
        }
    }

    private func aspectFitRect(videoSize: CGSize, in container: CGRect) -> CGRect {
        guard videoSize.width > 0, videoSize.height > 0, container.width > 0, container.height > 0 else {
            return .zero
        }

        let scale = min(container.width / videoSize.width, container.height / videoSize.height)
        let scaledSize = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        let origin = CGPoint(
            x: container.midX - (scaledSize.width / 2),
            y: container.midY - (scaledSize.height / 2)
        )
        return CGRect(origin: origin, size: scaledSize)
    }

    private func mappedPoint(x: Double, y: Double, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + (rect.width * x),
            y: rect.minY + (rect.height * y)
        )
    }
}

private struct GarageSlowMotionPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> GaragePlayerContainerView {
        let view = GaragePlayerContainerView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: GaragePlayerContainerView, context: Context) {
        uiView.player = player
    }
}

private final class GaragePlayerContainerView: UIView {
    private let playerLayer = AVPlayerLayer()

    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

@MainActor
private final class GarageSlowMotionPlaybackController: ObservableObject {
    @Published var currentTime = 0.0

    let player: AVPlayer

    private var timeObserverToken: Any?
    private var playbackEndObserver: NSObjectProtocol?

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0 / 60.0, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTime = max(CMTimeGetSeconds(time), 0)
            }
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.pause()
        }
    }

    deinit {
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
        }
    }

    func startSlowMotion() {
        replay()
    }

    func replay() {
        currentTime = 0
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player.playImmediately(atRate: 0.35)
    }

    func stop() {
        player.pause()
    }
}

private struct GarageEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.garage.theme,
            title: "No swing records yet",
            message: "Select a swing video from Photos to begin a cleaner review workflow.",
            actionTitle: "Select First Video",
            action: action
        )
    }
}


#Preview("Garage") {
    PreviewScreenContainer {
        GarageView()
    }
    .modelContainer(for: SwingRecord.self, inMemory: true)
}
```

## File: `LIFE-IN-SYNC/HabitStackView.swift`

```swift
import SwiftData
import SwiftUI

struct HabitStackView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query(sort: \HabitEntry.loggedAt, order: .reverse) private var entries: [HabitEntry]
    @State private var isShowingAddHabit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ModuleHeroCard(
                    module: .habitStack,
                    eyebrow: "First Live Module",
                    title: "Build recurring momentum with daily habits.",
                    message: "Create habits, log progress throughout the day, and keep a clear view of streaks and recent completion."
                )

                HabitOverviewCard(
                    habitCount: habits.count,
                    completedTodayCount: habits.filter(isHabitCompletedToday).count,
                    totalTodayProgress: entriesForToday.reduce(0) { $0 + $1.count }
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Today's Habits")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        Button {
                            isShowingAddHabit = true
                        } label: {
                            Label("Add Habit", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppModule.habitStack.theme.primary)
                    }

                    if habits.isEmpty {
                        HabitEmptyStateView {
                            isShowingAddHabit = true
                        }
                    } else {
                        ForEach(habits) { habit in
                            HabitCard(
                                habit: habit,
                                progressCount: progressCount(for: habit),
                                streakCount: streakCount(for: habit),
                                lastLoggedAt: lastLoggedAt(for: habit),
                                incrementAction: { logProgress(for: habit) },
                                decrementAction: { removeProgress(for: habit) }
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppModule.habitStack.theme.screenGradient)
        .sheet(isPresented: $isShowingAddHabit) {
            AddHabitSheet { name, targetCount in
                addHabit(name: name, targetCount: targetCount)
            }
        }
    }

    private var entriesForToday: [HabitEntry] {
        entries.filter { Calendar.current.isDateInToday($0.loggedAt) }
    }

    private func progressCount(for habit: Habit) -> Int {
        entriesForToday
            .filter { $0.habitID == habit.id }
            .reduce(0) { $0 + $1.count }
    }

    private func isHabitCompletedToday(_ habit: Habit) -> Bool {
        progressCount(for: habit) >= habit.targetCount
    }

    private func lastLoggedAt(for habit: Habit) -> Date? {
        entries.first(where: { $0.habitID == habit.id })?.loggedAt
    }

    private func streakCount(for habit: Habit) -> Int {
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: entries.filter { $0.habitID == habit.id }) {
            calendar.startOfDay(for: $0.loggedAt)
        }

        var streak = 0
        var cursor = calendar.startOfDay(for: .now)

        while let dayEntries = groupedByDay[cursor] {
            let total = dayEntries.reduce(0) { $0 + $1.count }
            if total < habit.targetCount {
                break
            }
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return streak
    }

    private func addHabit(name: String, targetCount: Int) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            return
        }

        let habit = Habit(name: trimmedName, targetCount: targetCount)
        modelContext.insert(habit)
    }

    private func logProgress(for habit: Habit) {
        let entry = HabitEntry(habitID: habit.id, habitName: habit.name)
        modelContext.insert(entry)
    }

    private func removeProgress(for habit: Habit) {
        guard let latestEntry = entries.first(where: {
            $0.habitID == habit.id && Calendar.current.isDateInToday($0.loggedAt)
        }) else {
            return
        }

        modelContext.delete(latestEntry)
    }
}

private struct HabitOverviewCard: View {
    let habitCount: Int
    let completedTodayCount: Int
    let totalTodayProgress: Int

    var body: some View {
        ModuleSnapshotCard(title: "Today Snapshot") {
            HStack(spacing: 12) {
                ModuleMetricChip(theme: AppModule.habitStack.theme, title: "Habits", value: "\(habitCount)")
                ModuleMetricChip(theme: AppModule.habitStack.theme, title: "Completed", value: "\(completedTodayCount)")
                ModuleMetricChip(theme: AppModule.habitStack.theme, title: "Logs", value: "\(totalTodayProgress)")
            }
        }
    }
}

private struct HabitEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.habitStack.theme,
            title: "No habits yet",
            message: "Start with one recurring behavior you want to reinforce daily. Habit Stack will track progress and streaks from there.",
            actionTitle: "Create First Habit",
            action: action
        )
    }
}

private struct HabitCard: View {
    let habit: Habit
    let progressCount: Int
    let streakCount: Int
    let lastLoggedAt: Date?
    let incrementAction: () -> Void
    let decrementAction: () -> Void

    private var progressValue: Double {
        guard habit.targetCount > 0 else { return 0 }
        return min(Double(progressCount) / Double(habit.targetCount), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(habit.name)
                        .font(.headline)
                    Text("\(progressCount) of \(habit.targetCount) today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Label("\(streakCount) day streak", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(AppModule.habitStack.theme.primary)
                    if let lastLoggedAt {
                        Text(lastLoggedAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ProgressView(value: progressValue)
                .tint(AppModule.habitStack.theme.primary)

            HStack {
                Button {
                    decrementAction()
                } label: {
                    Label("Undo", systemImage: "minus")
                }
                .buttonStyle(.bordered)
                .disabled(progressCount == 0)

                Spacer()

                Button {
                    incrementAction()
                } label: {
                    Label("Log Progress", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppModule.habitStack.theme.primary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(progressCount >= habit.targetCount ? AppModule.habitStack.theme.primary.opacity(0.4) : .clear, lineWidth: 1.5)
        )
    }
}

private struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var targetCount = 1
    let onSave: (String, Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit Details") {
                    TextField("Habit name", text: $name)

                    Stepper(value: $targetCount, in: 1 ... 12) {
                        Text("Daily target: \(targetCount)")
                    }
                }
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, targetCount)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview("Habit Stack") {
    PreviewScreenContainer {
        HabitStackView()
    }
    .modelContainer(for: [Habit.self, HabitEntry.self], inMemory: true)
}
```

## File: `LIFE-IN-SYNC/IronTempleView.swift`

```swift
import SwiftData
import SwiftUI

struct IronTempleView: View {
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.performedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var isShowingAddTemplate = false
    @State private var isShowingLogSession = false
    @State private var selectedTab: ModuleHubTab = .overview

    var body: some View {
        ModuleHubScaffold(
            module: .ironTemple,
            title: "Keep training simple and repeatable.",
            subtitle: "Separate template building from session execution and keep entries clean.",
            currentState: "\(sessions.count) sessions logged and \(templates.count) templates available.",
            nextAttention: templates.isEmpty ? "Build your first template to remove friction." : "Log your next workout session today.",
            tabs: [.overview, .builder, .advisor],
            selectedTab: $selectedTab
        ) {
            switch selectedTab {
            case .overview:
                IronTempleOverviewTab(
                    sessions: sessions,
                    templateCount: templates.count
                ) {
                    isShowingLogSession = true
                }
            case .builder:
                IronTempleBuilderTab(templates: templates) {
                    isShowingAddTemplate = true
                }
            case .advisor:
                ModuleEmptyStateCard(
                    theme: AppModule.ironTemple.theme,
                    title: "Advisor is optional",
                    message: "Use user-triggered prompts for workout decisions. Any write action requires explicit approval.",
                    actionTitle: "Log Session",
                    action: { isShowingLogSession = true }
                )
            default:
                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            ModuleBottomActionBar(
                theme: AppModule.ironTemple.theme,
                title: "Log Session",
                systemImage: "plus"
            ) {
                isShowingLogSession = true
            }
        }
        .sheet(isPresented: $isShowingAddTemplate) {
            AddWorkoutTemplateSheet()
        }
        .sheet(isPresented: $isShowingLogSession) {
            LogWorkoutSessionSheet(templates: templates)
        }
    }
}

private struct IronTempleOverviewTab: View {
    let sessions: [WorkoutSession]
    let templateCount: Int
    let logSession: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            IronTempleOverviewCard(
                templateCount: templateCount,
                sessionCount: sessions.count,
                totalMinutes: sessions.reduce(0) { $0 + $1.durationMinutes }
            )

            ModuleActivityFeedSection(title: "Recent Sessions") {
                if sessions.isEmpty {
                    IronTempleEmptyStateView(
                        title: "No sessions logged",
                        message: "Record a recent workout to start building your history.",
                        actionTitle: "Log Session",
                        action: logSession
                    )
                } else {
                    ForEach(sessions.prefix(8)) { session in
                        WorkoutSessionCard(session: session)
                    }
                }
            }
        }
    }
}

private struct IronTempleBuilderTab: View {
    let templates: [WorkoutTemplate]
    let addTemplate: () -> Void

    var body: some View {
        ModuleActivityFeedSection(title: "Workout Templates") {
            HStack {
                Spacer()
                Button("Add Template", action: addTemplate)
                    .buttonStyle(.bordered)
            }

            if templates.isEmpty {
                IronTempleEmptyStateView(
                    title: "No templates yet",
                    message: "Create a workout template so you can log sessions against a repeatable structure.",
                    actionTitle: "Create Template",
                    action: addTemplate
                )
            } else {
                ForEach(templates) { template in
                    WorkoutTemplateCard(template: template)
                }
            }
        }
    }
}

private struct IronTempleOverviewCard: View {
    let templateCount: Int
    let sessionCount: Int
    let totalMinutes: Int

    var body: some View {
        ModuleVisualizationContainer(title: "Training Snapshot") {
            HStack(spacing: 12) {
                ModuleMetricChip(theme: AppModule.ironTemple.theme, title: "Templates", value: "\(templateCount)")
                ModuleMetricChip(theme: AppModule.ironTemple.theme, title: "Sessions", value: "\(sessionCount)")
                ModuleMetricChip(theme: AppModule.ironTemple.theme, title: "Minutes", value: "\(totalMinutes)")
            }
        }
    }
}

private struct WorkoutTemplateCard: View {
    let template: WorkoutTemplate

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(AppModule.ironTemple.theme.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                Text(template.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct WorkoutSessionCard: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.templateName)
                    .font(.headline)
                Text(session.performedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(session.durationMinutes) min")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppModule.ironTemple.theme.primary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct IronTempleEmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.ironTemple.theme,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
    }
}

private struct AddWorkoutTemplateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Details") {
                    TextField("Template name", text: $name)
                }
            }
            .navigationTitle("New Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedName.isEmpty == false else {
                            return
                        }

                        modelContext.insert(WorkoutTemplate(name: trimmedName))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct LogWorkoutSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTemplateName = ""
    @State private var durationMinutes = 45
    @State private var performedAt = Date()
    let templates: [WorkoutTemplate]

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Details") {
                    Picker("Template", selection: $selectedTemplateName) {
                        ForEach(templates, id: \.name) { template in
                            Text(template.name).tag(template.name)
                        }
                    }

                    Stepper(value: $durationMinutes, in: 5 ... 180, step: 5) {
                        Text("Duration: \(durationMinutes) min")
                    }

                    DatePicker("Performed", selection: $performedAt)
                }
            }
            .navigationTitle("Log Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard selectedTemplateName.isEmpty == false else {
                            return
                        }

                        modelContext.insert(
                            WorkoutSession(
                                templateName: selectedTemplateName,
                                performedAt: performedAt,
                                durationMinutes: durationMinutes
                            )
                        )
                        dismiss()
                    }
                    .disabled(selectedTemplateName.isEmpty)
                }
            }
            .onAppear {
                if selectedTemplateName.isEmpty {
                    selectedTemplateName = templates.first?.name ?? ""
                }
            }
        }
    }
}

#Preview("Iron Temple") {
    PreviewScreenContainer {
        IronTempleView()
    }
    .modelContainer(for: [WorkoutTemplate.self, WorkoutSession.self], inMemory: true)
}
```

## File: `LIFE-IN-SYNC/Item.swift`

```swift
import Foundation
import SwiftData

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }
}

enum SwingPhase: String, Codable, CaseIterable, Identifiable {
    case address
    case takeaway
    case shaftParallel
    case topOfBackswing
    case transition
    case earlyDownswing
    case impact
    case followThrough

    var id: String { rawValue }

    var title: String {
        switch self {
        case .address:
            "Address"
        case .takeaway:
            "Takeaway"
        case .shaftParallel:
            "Shaft Parallel"
        case .topOfBackswing:
            "Top of Backswing"
        case .transition:
            "Transition"
        case .earlyDownswing:
            "Early Downswing"
        case .impact:
            "Impact"
        case .followThrough:
            "Follow Through"
        }
    }

    var reviewTitle: String {
        switch self {
        case .address:
            "Setup"
        case .takeaway:
            "Takeaway Start"
        case .shaftParallel:
            "Lead Arm Parallel"
        case .topOfBackswing:
            "Top of Swing"
        case .transition:
            "Transition"
        case .earlyDownswing:
            "Early Downswing"
        case .impact:
            "Impact"
        case .followThrough:
            "Finish"
        }
    }
}

enum KeyframeValidationStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case approved
    case flagged

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending:
            "Pending"
        case .approved:
            "Approved"
        case .flagged:
            "Flagged"
        }
    }
}

enum SwingJointName: String, Codable, CaseIterable, Identifiable {
    case nose
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle

    var id: String { rawValue }
}

struct SwingJoint: Codable, Hashable, Identifiable {
    var name: SwingJointName
    var x: Double
    var y: Double
    var confidence: Double

    var id: SwingJointName { name }
}

struct SwingFrame: Codable, Hashable, Identifiable {
    var timestamp: Double
    var joints: [SwingJoint]
    var confidence: Double

    var id: Double { timestamp }
}

struct KeyFrame: Codable, Hashable, Identifiable {
    var phase: SwingPhase
    var frameIndex: Int
    var source: KeyFrameSource = .automatic
    var reviewStatus: KeyframeValidationStatus = .pending

    var id: SwingPhase { phase }

    init(
        phase: SwingPhase,
        frameIndex: Int,
        source: KeyFrameSource = .automatic,
        reviewStatus: KeyframeValidationStatus = .pending
    ) {
        self.phase = phase
        self.frameIndex = frameIndex
        self.source = source
        self.reviewStatus = reviewStatus
    }

    private enum CodingKeys: String, CodingKey {
        case phase
        case frameIndex
        case source
        case reviewStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phase = try container.decode(SwingPhase.self, forKey: .phase)
        frameIndex = try container.decode(Int.self, forKey: .frameIndex)
        source = try container.decodeIfPresent(KeyFrameSource.self, forKey: .source) ?? .automatic
        reviewStatus = try container.decodeIfPresent(KeyframeValidationStatus.self, forKey: .reviewStatus) ?? .pending
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phase, forKey: .phase)
        try container.encode(frameIndex, forKey: .frameIndex)
        try container.encode(source, forKey: .source)
        try container.encode(reviewStatus, forKey: .reviewStatus)
    }
}

enum KeyFrameSource: String, Codable, CaseIterable, Identifiable {
    case automatic
    case adjusted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            "Auto"
        case .adjusted:
            "Adjusted"
        }
    }
}

enum HandAnchorSource: String, Codable, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            "Auto"
        case .manual:
            "Manual"
        }
    }
}

struct HandAnchor: Codable, Hashable, Identifiable {
    var phase: SwingPhase
    var x: Double
    var y: Double
    var source: HandAnchorSource = .automatic

    var id: SwingPhase { phase }

    init(
        phase: SwingPhase,
        x: Double,
        y: Double,
        source: HandAnchorSource = .automatic
    ) {
        self.phase = phase
        self.x = x
        self.y = y
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case phase
        case x
        case y
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phase = try container.decode(SwingPhase.self, forKey: .phase)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        source = try container.decodeIfPresent(HandAnchorSource.self, forKey: .source) ?? .automatic
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phase, forKey: .phase)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(source, forKey: .source)
    }
}

struct PathPoint: Codable, Hashable, Identifiable {
    var sequence: Int
    var x: Double
    var y: Double

    var id: Int { sequence }
}

struct AnalysisResult: Codable, Hashable {
    var issues: [String]
    var highlights: [String]
    var summary: String
}

@Model
final class CompletionRecord {
    var completedAt: Date
    var sourceModuleID: String

    init(completedAt: Date = .now, sourceModuleID: String) {
        self.completedAt = completedAt
        self.sourceModuleID = sourceModuleID
    }
}

@Model
final class TagRecord {
    var name: String

    init(name: String) {
        self.name = name
    }
}

@Model
final class NoteRecord {
    var body: String
    var createdAt: Date

    init(body: String, createdAt: Date = .now) {
        self.body = body
        self.createdAt = createdAt
    }
}

@Model
final class Habit {
    var id: UUID
    var name: String
    var targetCount: Int
    var createdAt: Date

    init(id: UUID = UUID(), name: String, targetCount: Int = 1, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.targetCount = targetCount
        self.createdAt = createdAt
    }
}

@Model
final class HabitEntry {
    var habitID: UUID
    var habitName: String
    var count: Int
    var loggedAt: Date

    init(habitID: UUID, habitName: String, count: Int = 1, loggedAt: Date = .now) {
        self.habitID = habitID
        self.habitName = habitName
        self.count = count
        self.loggedAt = loggedAt
    }
}

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var priority: String
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        priority: String = TaskPriority.medium.rawValue,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

@Model
final class CalendarEvent {
    var title: String
    var startDate: Date
    var endDate: Date

    init(title: String, startDate: Date, endDate: Date) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
    }
}

@Model
final class SupplyItem {
    var title: String
    var category: String
    var isPurchased: Bool

    init(title: String, category: String = "General", isPurchased: Bool = false) {
        self.title = title
        self.category = category
        self.isPurchased = isPurchased
    }
}

@Model
final class ExpenseRecord {
    var title: String
    var amount: Double
    var category: String
    var recordedAt: Date

    init(title: String, amount: Double, category: String, recordedAt: Date = .now) {
        self.title = title
        self.amount = amount
        self.category = category
        self.recordedAt = recordedAt
    }
}

@Model
final class BudgetRecord {
    var title: String
    var limitAmount: Double
    var periodLabel: String

    init(title: String, limitAmount: Double, periodLabel: String = "Monthly") {
        self.title = title
        self.limitAmount = limitAmount
        self.periodLabel = periodLabel
    }
}

@Model
final class WorkoutTemplate {
    var name: String
    var createdAt: Date

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class WorkoutSession {
    var templateName: String
    var performedAt: Date
    var durationMinutes: Int

    init(templateName: String, performedAt: Date = .now, durationMinutes: Int = 0) {
        self.templateName = templateName
        self.performedAt = performedAt
        self.durationMinutes = durationMinutes
    }
}

@Model
final class StudyEntry {
    var title: String
    var passageReference: String
    var notes: String
    var createdAt: Date

    init(title: String, passageReference: String, notes: String = "", createdAt: Date = .now) {
        self.title = title
        self.passageReference = passageReference
        self.notes = notes
        self.createdAt = createdAt
    }
}

@Model
final class SwingRecord {
    var title: String
    var createdAt: Date
    var mediaFilename: String?
    var mediaFileBookmark: Data?
    var reviewMasterFilename: String?
    var reviewMasterBookmark: Data?
    var exportAssetFilename: String?
    var exportAssetBookmark: Data?
    var notes: String
    var frameRate: Double
    var swingFrames: [SwingFrame]
    var keyFrames: [KeyFrame]
    var keyframeValidationStatus: KeyframeValidationStatus
    var handAnchors: [HandAnchor]
    var pathPoints: [PathPoint]
    var analysisResult: AnalysisResult?

    init(
        title: String,
        createdAt: Date = .now,
        mediaFilename: String? = nil,
        mediaFileBookmark: Data? = nil,
        reviewMasterFilename: String? = nil,
        reviewMasterBookmark: Data? = nil,
        exportAssetFilename: String? = nil,
        exportAssetBookmark: Data? = nil,
        notes: String = "",
        frameRate: Double = 0,
        swingFrames: [SwingFrame] = [],
        keyFrames: [KeyFrame] = [],
        keyframeValidationStatus: KeyframeValidationStatus = .pending,
        handAnchors: [HandAnchor] = [],
        pathPoints: [PathPoint] = [],
        analysisResult: AnalysisResult? = nil
    ) {
        self.title = title
        self.createdAt = createdAt
        self.mediaFilename = mediaFilename
        self.mediaFileBookmark = mediaFileBookmark
        self.reviewMasterFilename = reviewMasterFilename
        self.reviewMasterBookmark = reviewMasterBookmark
        self.exportAssetFilename = exportAssetFilename
        self.exportAssetBookmark = exportAssetBookmark
        self.notes = notes
        self.frameRate = frameRate
        self.swingFrames = swingFrames
        self.keyFrames = keyFrames
        self.keyframeValidationStatus = keyframeValidationStatus
        self.handAnchors = handAnchors
        self.pathPoints = pathPoints
        self.analysisResult = analysisResult
    }

    var preferredReviewFilename: String? {
        normalizedFilename(reviewMasterFilename) ?? normalizedFilename(mediaFilename)
    }

    var preferredExportFilename: String? {
        normalizedFilename(exportAssetFilename)
    }

    var isUsingLegacySingleAsset: Bool {
        normalizedFilename(reviewMasterFilename) == nil && normalizedFilename(mediaFilename) != nil
    }

    private func normalizedFilename(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func reviewStatus(for phase: SwingPhase) -> KeyframeValidationStatus {
        keyFrames.first(where: { $0.phase == phase })?.reviewStatus ?? .pending
    }

    var approvedCheckpointCount: Int {
        SwingPhase.allCases.filter { reviewStatus(for: $0) == .approved }.count
    }

    var flaggedCheckpointCount: Int {
        SwingPhase.allCases.filter { reviewStatus(for: $0) == .flagged }.count
    }

    var pendingCheckpointCount: Int {
        max(SwingPhase.allCases.count - approvedCheckpointCount - flaggedCheckpointCount, 0)
    }

    var allCheckpointsApproved: Bool {
        keyFrames.count == SwingPhase.allCases.count && SwingPhase.allCases.allSatisfy { reviewStatus(for: $0) == .approved }
    }

    func refreshKeyframeValidationStatus() {
        if allCheckpointsApproved {
            keyframeValidationStatus = .approved
        } else if flaggedCheckpointCount > 0 {
            keyframeValidationStatus = .flagged
        } else {
            keyframeValidationStatus = .pending
        }
    }

    func hydrateCheckpointStatusesFromAggregateIfNeeded() {
        guard
            keyFrames.isEmpty == false,
            keyframeValidationStatus != .pending,
            keyFrames.allSatisfy({ $0.reviewStatus == .pending })
        else {
            return
        }

        for index in keyFrames.indices {
            keyFrames[index].reviewStatus = keyframeValidationStatus
        }
    }
}
```

## File: `LIFE-IN-SYNC/LIFE_IN_SYNCApp.swift`

```swift
import SwiftData
import SwiftUI

@main
struct LifeInSyncApp: App {
    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CompletionRecord.self,
            TagRecord.self,
            NoteRecord.self,
            Habit.self,
            HabitEntry.self,
            TaskItem.self,
            CalendarEvent.self,
            SupplyItem.self,
            ExpenseRecord.self,
            BudgetRecord.self,
            WorkoutTemplate.self,
            WorkoutSession.self,
            StudyEntry.self,
            SwingRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

## File: `LIFE-IN-SYNC/LaunchAffirmationView.swift`

```swift
import SwiftUI

struct LaunchAffirmationView: View {
    private let entry = LaunchAffirmationEntry.dailySelection

    var body: some View {
        ZStack {
            AppModule.dashboard.theme.screenGradient
                .ignoresSafeArea()

            VStack(spacing: ModuleSpacing.xLarge) {
                VStack(spacing: ModuleSpacing.medium) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(AppModule.dashboard.theme.primary)

                    Text("LIFE IN SYNC")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .tracking(3)
                        .foregroundStyle(AppModule.dashboard.theme.accentText)

                    Text(entry.title)
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text(entry.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)

                    Text(entry.attribution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ProgressView()
                    .tint(AppModule.dashboard.theme.primary)
                    .frame(width: 120)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, ModuleSpacing.xLarge)
        }
        .accessibilityIdentifier("launch-affirmation-screen")
    }
}

private struct LaunchAffirmationEntry {
    let title: String
    let message: String
    let attribution: String

    static var dailySelection: LaunchAffirmationEntry {
        let entries = fallbackEntries
        let calendar = Calendar.autoupdatingCurrent
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .now
        let dayOffset = calendar.dateComponents([.day], from: referenceDate, to: .now).day ?? 0
        let index = abs(dayOffset) % entries.count
        return entries[index]
    }

    private static let fallbackEntries: [LaunchAffirmationEntry] = [
        LaunchAffirmationEntry(
            title: "Enter the day with order.",
            message: "Let the next right action be obvious, calm, and local to what matters.",
            attribution: "Offline fallback"
        ),
        LaunchAffirmationEntry(
            title: "Build quietly. Finish clearly.",
            message: "Progress compounds when your system stays dependable under ordinary days.",
            attribution: "Offline fallback"
        ),
        LaunchAffirmationEntry(
            title: "Keep the essentials in view.",
            message: "Attention is a limited asset. Give it to the work that keeps life aligned.",
            attribution: "Offline fallback"
        ),
        LaunchAffirmationEntry(
            title: "Move with clarity, not noise.",
            message: "A useful system should lower friction, shorten hesitation, and keep truth visible.",
            attribution: "Offline fallback"
        )
    ]
}

#Preview("Launch Affirmation") {
    LaunchAffirmationView()
}
```

## File: `LIFE-IN-SYNC/ModuleMenuView.swift`

```swift
import SwiftUI

struct ModuleMenuView: View {
    @Binding var selectedModule: AppModule
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(AppModule.allCases) { module in
            Button {
                selectedModule = module
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: module.systemImage)
                        .frame(width: 24)
                        .foregroundStyle(module.theme.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(module.title)
                            .font(.headline)
                        Text(module.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selectedModule == module {
                        Image(systemName: "checkmark")
                            .foregroundStyle(module.theme.primary)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("module-menu-\(module.rawValue)")
            .listRowBackground(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(module == selectedModule ? module.theme.chipBackground : .clear)
            )
        }
        .navigationTitle("Modules")
    }
}

#Preview("Module Menu Dashboard") {
    NavigationStack {
        ModuleMenuView(selectedModule: .constant(.dashboard))
    }
}

#Preview("Module Menu Calendar Selected") {
    NavigationStack {
        ModuleMenuView(selectedModule: .constant(.calendar))
    }
}
```

## File: `LIFE-IN-SYNC/ModuleTheme.swift`

```swift
import SwiftUI

struct ModuleTheme {
    let primary: Color
    let secondary: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let accentText: Color

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.32), secondary.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var screenGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var chipBackground: Color {
        primary.opacity(0.14)
    }

    var surfaceSecondary: Color {
        primary.opacity(0.08)
    }

    var surfaceInteractive: Color {
        primary.opacity(0.14)
    }

    var borderSubtle: Color {
        primary.opacity(0.18)
    }

    var borderStrong: Color {
        primary.opacity(0.4)
    }

    var textPrimary: Color {
        .primary
    }

    var textSecondary: Color {
        .secondary
    }

    var textMuted: Color {
        .secondary.opacity(0.85)
    }
}
```

## File: `LIFE-IN-SYNC/SharedModuleUI.swift`

```swift
import SwiftData
import SwiftUI

enum ModuleHubTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case entries = "Entries"
    case advisor = "Advisor"
    case builder = "Builder"
    case records = "Records"
    case review = "Review"

    var id: String { rawValue }
}

enum HubSectionSpacing {
    static let outer: CGFloat = 20
    static let content: CGFloat = 14
}

enum ModuleSpacing {
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 20
    static let xLarge: CGFloat = 24
}

enum ModuleCornerRadius {
    static let card: CGFloat = 20
    static let chip: CGFloat = 16
    static let row: CGFloat = 18
    static let medium: CGFloat = 18
    static let hero: CGFloat = 24
}

enum ModuleTypography {
    static let sectionTitle: Font = .headline
    static let cardTitle: Font = .headline
    static let metricValue: Font = .title3.weight(.bold)
    static let supportingLabel: Font = .caption
}

struct PreviewScreenContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            content
        }
    }
}

struct ModuleScreen<Content: View>: View {
    let theme: ModuleTheme
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubSectionSpacing.outer) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .tint(theme.primary)
        .background(theme.screenGradient)
    }
}

struct ModuleHeader: View {
    let theme: ModuleTheme
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.textPrimary)
            Text(subtitle)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(theme.heroGradient, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.hero, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.hero, style: .continuous)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}

struct ModuleRowSurface<Content: View>: View {
    let theme: ModuleTheme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(theme.surfaceSecondary, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous)
                .stroke(theme.borderSubtle, lineWidth: 1)
        )
    }
}

@MainActor
enum PreviewCatalog {
    static let emptyApp = makeContainer()
    static let populatedApp = makeContainer(seed: .populated)

    private enum SeedStyle {
        case empty
        case populated
    }

    private static func makeContainer(seed: SeedStyle = .empty) -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: Schema([
                    Habit.self,
                    HabitEntry.self,
                    TaskItem.self,
                    CalendarEvent.self,
                    SupplyItem.self,
                    ExpenseRecord.self,
                    BudgetRecord.self,
                    WorkoutTemplate.self,
                    WorkoutSession.self,
                    StudyEntry.self,
                    SwingRecord.self
                ]),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )

            if seed == .populated {
                seedPopulatedData(into: container.mainContext)
            }

            return container
        } catch {
            fatalError("Unable to create preview container: \(error)")
        }
    }

    private static func seedPopulatedData(into context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        let morningPrayer = Habit(
            name: "Morning Prayer",
            targetCount: 1,
            createdAt: calendar.date(byAdding: .day, value: -21, to: now) ?? now
        )
        let walk = Habit(
            name: "Evening Walk",
            targetCount: 2,
            createdAt: calendar.date(byAdding: .day, value: -10, to: now) ?? now
        )

        let habits = [morningPrayer, walk]
        habits.forEach(context.insert)

        let habitEntries = [
            HabitEntry(habitID: morningPrayer.id, habitName: morningPrayer.name, loggedAt: calendar.date(byAdding: .hour, value: 7, to: startOfToday) ?? now),
            HabitEntry(habitID: walk.id, habitName: walk.name, loggedAt: calendar.date(byAdding: .hour, value: 18, to: startOfToday) ?? now),
            HabitEntry(habitID: walk.id, habitName: walk.name, loggedAt: calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .hour, value: 18, to: startOfToday) ?? now) ?? now),
            HabitEntry(habitID: walk.id, habitName: walk.name, loggedAt: calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .hour, value: 19, to: startOfToday) ?? now) ?? now)
        ]
        habitEntries.forEach(context.insert)

        let tasks = [
            TaskItem(
                title: "Ship preview workflow",
                priority: TaskPriority.high.rawValue,
                dueDate: calendar.date(byAdding: .hour, value: 6, to: now),
                createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            TaskItem(
                title: "Refine dashboard module pulse",
                priority: TaskPriority.medium.rawValue,
                dueDate: calendar.date(byAdding: .day, value: 1, to: now),
                createdAt: calendar.date(byAdding: .hour, value: -8, to: now) ?? now
            ),
            TaskItem(
                title: "Review launch affirmation tone",
                priority: TaskPriority.low.rawValue,
                dueDate: nil,
                isCompleted: true,
                createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now
            )
        ]
        tasks.forEach(context.insert)

        let standupStart = calendar.date(byAdding: .hour, value: 9, to: startOfToday) ?? now
        let workoutStart = calendar.date(byAdding: .hour, value: 17, to: startOfToday) ?? now
        let events = [
            CalendarEvent(
                title: "Project Standup",
                startDate: standupStart,
                endDate: calendar.date(byAdding: .minute, value: 30, to: standupStart) ?? standupStart
            ),
            CalendarEvent(
                title: "Gym Block",
                startDate: workoutStart,
                endDate: calendar.date(byAdding: .hour, value: 1, to: workoutStart) ?? workoutStart
            ),
            CalendarEvent(
                title: "Budget Review",
                startDate: calendar.date(byAdding: .day, value: 1, to: calendar.date(byAdding: .hour, value: 11, to: startOfToday) ?? now) ?? now,
                endDate: calendar.date(byAdding: .day, value: 1, to: calendar.date(byAdding: .hour, value: 12, to: startOfToday) ?? now) ?? now
            )
        ]
        events.forEach(context.insert)

        let supplyItems = [
            SupplyItem(title: "Greek yogurt", category: "Groceries"),
            SupplyItem(title: "Trash bags", category: "Household"),
            SupplyItem(title: "Protein powder", category: "Personal"),
            SupplyItem(title: "Paper towels", category: "Household", isPurchased: true)
        ]
        supplyItems.forEach(context.insert)

        let expenses = [
            ExpenseRecord(title: "Gas", amount: 48.20, category: "Transport", recordedAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now),
            ExpenseRecord(title: "Groceries", amount: 86.45, category: "Food", recordedAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
        ]
        expenses.forEach(context.insert)

        let budgets = [
            BudgetRecord(title: "Food", limitAmount: 500, periodLabel: "Monthly"),
            BudgetRecord(title: "Transport", limitAmount: 180, periodLabel: "Monthly")
        ]
        budgets.forEach(context.insert)

        let workoutTemplates = [
            WorkoutTemplate(name: "Upper Body Strength", createdAt: calendar.date(byAdding: .day, value: -14, to: now) ?? now),
            WorkoutTemplate(name: "Conditioning Circuit", createdAt: calendar.date(byAdding: .day, value: -8, to: now) ?? now)
        ]
        workoutTemplates.forEach(context.insert)

        let workouts = [
            WorkoutSession(templateName: "Upper Body", performedAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now, durationMinutes: 55),
            WorkoutSession(templateName: "Run", performedAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now, durationMinutes: 32)
        ]
        workouts.forEach(context.insert)

        let studyEntries = [
            StudyEntry(
                title: "Abide in the Vine",
                passageReference: "John 15:1-11",
                notes: "The strongest note is dependence before output.",
                createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            StudyEntry(
                title: "Renewing the Mind",
                passageReference: "Romans 12:1-2",
                notes: "Transformation feels more like steady surrender than one dramatic turn.",
                createdAt: calendar.date(byAdding: .day, value: -4, to: now) ?? now
            )
        ]
        studyEntries.forEach(context.insert)

        let swings = [
            SwingRecord(title: "7 Iron - Range Session", createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now, notes: "Best strikes came with slower tempo."),
            SwingRecord(title: "Driver - Tee Box Check", createdAt: calendar.date(byAdding: .day, value: -6, to: now) ?? now, notes: "Ball started right when setup drifted open.")
        ]
        swings.forEach(context.insert)

        try? context.save()
    }
}

struct ModuleHubScaffold<Content: View>: View {
    let module: AppModule
    let title: String
    let subtitle: String
    let currentState: String
    let nextAttention: String
    var showsCommandCenterChrome = true
    let tabs: [ModuleHubTab]
    @Binding var selectedTab: ModuleHubTab
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubSectionSpacing.outer) {
                if showsCommandCenterChrome {
                    ModuleHeroCard(
                        module: module,
                        eyebrow: "Command Center",
                        title: title,
                        message: subtitle
                    )

                    HubStatusCard(
                        module: module,
                        title: "Current State",
                        bodyText: currentState
                    )

                    HubStatusCard(
                        module: module,
                        title: "Next Attention",
                        bodyText: nextAttention
                    )
                }

                HubTabPicker(tabs: tabs, selectedTab: $selectedTab, theme: module.theme)

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .tint(module.theme.primary)
        .background(module.theme.screenGradient)
    }
}

private struct HubStatusCard: View {
    let module: AppModule
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: HubSectionSpacing.content) {
            Text(title)
                .font(ModuleTypography.cardTitle)
            Text(bodyText)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                .stroke(module.theme.primary.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct HubTabPicker: View {
    let tabs: [ModuleHubTab]
    @Binding var selectedTab: ModuleHubTab
    let theme: ModuleTheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(selectedTab == tab ? Color.white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, ModuleSpacing.xSmall)
                            .background(
                                RoundedRectangle(cornerRadius: ModuleSpacing.small, style: .continuous)
                                    .fill(selectedTab == tab ? theme.primary : theme.surfaceSecondary)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ModuleRootPlaceholderView: View {
    let module: AppModule
    let description: String
    let highlights: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ModuleHeroCard(
                    module: module,
                    eyebrow: "Module Root",
                    title: module.title,
                    message: description
                )

                ModuleFocusCard(module: module, highlights: highlights)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .tint(module.theme.primary)
        .background(module.theme.screenGradient)
    }
}

struct ModuleHeroCard: View {
    let module: AppModule
    let eyebrow: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(module.theme.accentText)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(module.theme.heroGradient, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous)
                .stroke(module.theme.primary.opacity(0.18), lineWidth: 1)
        )
    }
}

struct ModuleFocusCard: View {
    let module: AppModule
    let highlights: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Current Focus")
                .font(ModuleTypography.cardTitle)

            ForEach(highlights, id: \.self) { highlight in
                HStack(spacing: 10) {
                    Circle()
                        .fill(module.theme.primary)
                        .frame(width: 8, height: 8)
                    Text(highlight)
                        .foregroundStyle(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
    }
}

struct ModuleSnapshotCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.medium) {
            Text(title)
                .font(ModuleTypography.cardTitle)
            content
        }
        .padding(ModuleSpacing.medium)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
    }
}

struct ModuleMetricChip: View {
    let theme: ModuleTheme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(ModuleTypography.metricValue)
            Text(title)
                .font(ModuleTypography.supportingLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(theme.chipBackground, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.chip, style: .continuous))
    }
}

struct ModuleEmptyStateCard: View {
    let theme: ModuleTheme
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(ModuleTypography.cardTitle)
            Text(message)
                .foregroundStyle(.secondary)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
    }
}

struct ModuleVisualizationContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            Text(title)
                .font(ModuleTypography.cardTitle)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModuleSpacing.medium)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.card, style: .continuous))
    }
}

struct ModuleActivityFeedSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleSpacing.small) {
            Text(title)
                .font(ModuleTypography.sectionTitle)
            content
        }
    }
}

struct ModuleBottomActionBar: View {
    let theme: ModuleTheme
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}
```

## File: `LIFE-IN-SYNC/SupplyListView.swift`

```swift
import SwiftData
import SwiftUI

struct SupplyListView: View {
    @Query(sort: \SupplyItem.category) private var items: [SupplyItem]
    @State private var isShowingAddItem = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModuleHeroCard(
                    module: .supplyList,
                    eyebrow: "Live Module",
                    title: "Keep the shopping list clean.",
                    message: "Supply List stays focused on what to buy, how it is grouped, and what has already been picked up."
                )

                SupplyOverviewCard(
                    totalCount: items.count,
                    remainingCount: remainingItems.count,
                    purchasedCount: purchasedItems.count
                )

                if groupedRemainingItems.isEmpty {
                    SupplyEmptyStateView {
                        isShowingAddItem = true
                    }
                } else {
                    ModuleActivityFeedSection(title: "Remaining By Category") {
                        ForEach(groupedRemainingItems.keys.sorted(), id: \.self) { category in
                            if let categoryItems = groupedRemainingItems[category] {
                                SupplyCategorySection(
                                    category: category,
                                    items: categoryItems
                                )
                            }
                        }
                    }
                }

                if purchasedItems.isEmpty == false {
                    ModuleActivityFeedSection(title: "Purchased") {
                        ForEach(purchasedItems) { item in
                            SupplyItemRow(item: item)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppModule.supplyList.theme.screenGradient)
        .safeAreaInset(edge: .bottom) {
            ModuleBottomActionBar(
                theme: AppModule.supplyList.theme,
                title: "Add Item",
                systemImage: "plus"
            ) {
                isShowingAddItem = true
            }
        }
        .sheet(isPresented: $isShowingAddItem) {
            AddSupplyItemSheet()
        }
    }

    private var remainingItems: [SupplyItem] {
        items.filter { $0.isPurchased == false }
    }

    private var purchasedItems: [SupplyItem] {
        items.filter(\.isPurchased)
    }

    private var groupedRemainingItems: [String: [SupplyItem]] {
        Dictionary(grouping: remainingItems) { $0.category }
    }
}

private struct SupplyOverviewCard: View {
    let totalCount: Int
    let remainingCount: Int
    let purchasedCount: Int

    var body: some View {
        ModuleVisualizationContainer(title: "List Snapshot") {
            HStack(spacing: 12) {
                ModuleMetricChip(theme: AppModule.supplyList.theme, title: "Total", value: "\(totalCount)")
                ModuleMetricChip(theme: AppModule.supplyList.theme, title: "Remaining", value: "\(remainingCount)")
                ModuleMetricChip(theme: AppModule.supplyList.theme, title: "Purchased", value: "\(purchasedCount)")
            }
        }
    }
}

private struct SupplyCategorySection: View {
    let category: String
    let items: [SupplyItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category)
                .font(.headline)

            ForEach(items) { item in
                SupplyItemRow(item: item)
            }
        }
    }
}

private struct SupplyItemRow: View {
    @Bindable var item: SupplyItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                item.isPurchased.toggle()
            } label: {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isPurchased ? AppModule.supplyList.theme.primary : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.isPurchased, color: .secondary)
                Text(item.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }
}

private struct SupplyEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        ModuleEmptyStateCard(
            theme: AppModule.supplyList.theme,
            title: "No shopping items yet",
            message: "Add what you need to buy, group it by category, and mark items off as you go.",
            actionTitle: "Add First Item",
            action: action
        )
    }
}

private struct AddSupplyItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var category = "Groceries"

    private let categories = ["Groceries", "Household", "Personal", "Tech", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item name", text: $title)

                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
            }
            .navigationTitle("New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedTitle.isEmpty == false else {
                            return
                        }

                        modelContext.insert(
                            SupplyItem(
                                title: trimmedTitle,
                                category: category
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview("Supply List Empty") {
    PreviewScreenContainer {
        SupplyListView()
    }
    .modelContainer(PreviewCatalog.emptyApp)
}

#Preview("Supply List Grouped") {
    PreviewScreenContainer {
        SupplyListView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
```

## File: `LIFE-IN-SYNC/TaskProtocolView.swift`

```swift
import SwiftData
import SwiftUI

struct TaskProtocolView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @State private var isShowingAddTask = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModuleHeroCard(
                    module: .taskProtocol,
                    eyebrow: "Live Module",
                    title: "Keep the next task obvious.",
                    message: "Task Protocol tracks priority, due dates, and completion state without turning into a full project manager."
                )

                ModuleVisualizationContainer(title: "Task Snapshot") {
                    HStack(spacing: 12) {
                        ModuleMetricChip(theme: AppModule.taskProtocol.theme, title: "Open", value: "\(openTasks.count)")
                        ModuleMetricChip(theme: AppModule.taskProtocol.theme, title: "Due Soon", value: "\(dueSoonTasks.count)")
                        ModuleMetricChip(theme: AppModule.taskProtocol.theme, title: "Done", value: "\(completedTasks.count)")
                    }
                }

                ModuleActivityFeedSection(title: "Current Tasks") {
                    if tasks.isEmpty {
                        ModuleEmptyStateCard(
                            theme: AppModule.taskProtocol.theme,
                            title: "No tasks yet",
                            message: "Capture the next important action and keep the list short enough to stay useful.",
                            actionTitle: "Add First Task"
                        ) {
                            isShowingAddTask = true
                        }
                    } else {
                        ForEach(tasks) { task in
                            TaskRow(task: task)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppModule.taskProtocol.theme.screenGradient)
        .safeAreaInset(edge: .bottom) {
            ModuleBottomActionBar(
                theme: AppModule.taskProtocol.theme,
                title: "Add Task",
                systemImage: "plus"
            ) {
                isShowingAddTask = true
            }
        }
        .sheet(isPresented: $isShowingAddTask) {
            AddTaskSheet()
        }
    }

    private var openTasks: [TaskItem] {
        tasks.filter { $0.isCompleted == false }
    }

    private var completedTasks: [TaskItem] {
        tasks.filter(\.isCompleted)
    }

    private var dueSoonTasks: [TaskItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        return openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate <= cutoff
        }
    }
}

private struct TaskRow: View {
    @Bindable var task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            Button {
                task.isCompleted.toggle()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? AppModule.taskProtocol.theme.primary : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted, color: .secondary)
                Text(taskMetaLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: ModuleCornerRadius.row, style: .continuous))
    }

    private var taskMetaLine: String {
        if let dueDate = task.dueDate {
            return "\(task.priority.capitalized) priority • due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }

        return "\(task.priority.capitalized) priority"
    }
}

private struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var priority = TaskPriority.medium
    @State private var includesDueDate = false
    @State private var dueDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)

                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { option in
                            Text(option.rawValue.capitalized).tag(option)
                        }
                    }

                    Toggle("Set due date", isOn: $includesDueDate)

                    if includesDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmedTitle.isEmpty == false else { return }

                        modelContext.insert(
                            TaskItem(
                                title: trimmedTitle,
                                priority: priority.rawValue,
                                dueDate: includesDueDate ? dueDate : nil
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview("Task Protocol Empty") {
    PreviewScreenContainer {
        TaskProtocolView()
    }
    .modelContainer(PreviewCatalog.emptyApp)
}

#Preview("Task Protocol Populated") {
    PreviewScreenContainer {
        TaskProtocolView()
    }
    .modelContainer(PreviewCatalog.populatedApp)
}
```

## File: `LIFE-IN-SYNCTests/GarageDerivedReportsXCTests.swift`

```swift
import Foundation
import XCTest
@testable import LIFE_IN_SYNC

@MainActor
final class GarageDerivedReportsXCTests: XCTestCase {
    func testGarageReliabilityReportIsTrustedForApprovedCompleteSwing() {
        let anchors = makeFullAnchorSet()
        let record = makeWorkflowRecord(
            keyframeValidationStatus: .approved,
            anchors: anchors,
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)
        )

        let report = GarageReliability.report(for: record)

        XCTAssertEqual(report.status, .trusted)
        XCTAssertGreaterThanOrEqual(report.score, 84)
        XCTAssertTrue(report.checks.allSatisfy(\.passed))
    }

    func testGarageReliabilityReportStaysReviewableWhenPoseFallbackKeepsCoverageAlive() {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let record = SwingRecord(
            title: "Weak Reliability",
            mediaFilename: nil,
            frameRate: 60,
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .flagged,
            handAnchors: [],
            pathPoints: [],
            analysisResult: AnalysisResult(issues: [], highlights: [], summary: "Synthetic weak case.")
        )

        let report = GarageReliability.report(for: record)

        XCTAssertEqual(report.status, .review)
        XCTAssertGreaterThanOrEqual(report.score, 50)
        XCTAssertLessThan(report.score, 84)
        XCTAssertTrue(report.checks.contains(where: { $0.title == "Review Status" && $0.passed == false }))
        XCTAssertTrue(report.checks.contains(where: { $0.title == "Grip Coverage" && $0.passed == false }))
        XCTAssertTrue(report.checks.contains(where: { $0.title == "Video Source" && $0.passed == true }))
    }

    func testGarageCoachingReportProvidesActionableCueForTrustedSwing() {
        let anchors = makeFullAnchorSet()
        let record = makeWorkflowRecord(
            keyframeValidationStatus: .approved,
            anchors: anchors,
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)
        )

        let report = GarageCoaching.report(for: record)

        XCTAssertEqual(report.confidenceLabel, GarageReliabilityStatus.trusted.rawValue)
        XCTAssertFalse(report.cues.isEmpty)
        XCTAssertTrue(report.blockers.isEmpty)
    }

    func testGarageCoachingReportUsesReviewBlockersWhenPoseFallbackLeavesSwingInReview() {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let record = SwingRecord(
            title: "Weak Coaching",
            mediaFilename: nil,
            frameRate: 60,
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .flagged,
            handAnchors: [],
            pathPoints: [],
            analysisResult: AnalysisResult(issues: [], highlights: [], summary: "Synthetic weak case.")
        )

        let report = GarageCoaching.report(for: record)

        XCTAssertEqual(report.confidenceLabel, GarageReliabilityStatus.review.rawValue)
        XCTAssertFalse(report.cues.isEmpty)
        XCTAssertFalse(report.blockers.isEmpty)
    }

    func testGarageCoachingReportFlagsLongTempoAsCaution() {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = [
            KeyFrame(phase: .address, frameIndex: 0),
            KeyFrame(phase: .takeaway, frameIndex: 1),
            KeyFrame(phase: .shaftParallel, frameIndex: 2),
            KeyFrame(phase: .topOfBackswing, frameIndex: 8),
            KeyFrame(phase: .transition, frameIndex: 9),
            KeyFrame(phase: .earlyDownswing, frameIndex: 9),
            KeyFrame(phase: .impact, frameIndex: 9),
            KeyFrame(phase: .followThrough, frameIndex: 9)
        ]
        let anchors = makeFullAnchorSet()
        let record = SwingRecord(
            title: "Tempo Caution",
            mediaFilename: "workflow.mov",
            frameRate: 60,
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .approved,
            handAnchors: anchors,
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4),
            analysisResult: AnalysisResult(issues: [], highlights: [], summary: "Synthetic tempo case.")
        )

        let report = GarageCoaching.report(for: record)

        XCTAssertTrue(report.cues.contains(where: { $0.title == "Backswing Is Running Long" && $0.severity == GarageCoachingSeverity.caution }))
    }

    func testDetectKeyFramesMaintainsStrictPhaseOrdering() {
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: makeSyntheticSwingFrames())
        let byPhase = Dictionary(uniqueKeysWithValues: keyFrames.map { ($0.phase, $0.frameIndex) })

        let orderedPairs: [(SwingPhase, SwingPhase)] = [
            (.address, .takeaway),
            (.takeaway, .shaftParallel),
            (.shaftParallel, .topOfBackswing),
            (.topOfBackswing, .transition),
            (.transition, .earlyDownswing),
            (.earlyDownswing, .impact),
            (.impact, .followThrough)
        ]

        for (lhs, rhs) in orderedPairs {
            guard let lhsIndex = byPhase[lhs], let rhsIndex = byPhase[rhs] else {
                XCTFail("Missing expected phases: \(lhs) or \(rhs)")
                return
            }

            XCTAssertLessThanOrEqual(lhsIndex, rhsIndex, "Expected \(lhs) to be at or before \(rhs)")
        }
    }

    func testEarlyDownswingStaysBeforeImpactForLateDownswingProfile() {
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: makeLateDownswingDriftFrames())
        let byPhase = Dictionary(uniqueKeysWithValues: keyFrames.map { ($0.phase, $0.frameIndex) })

        guard
            let transition = byPhase[.transition],
            let earlyDownswing = byPhase[.earlyDownswing],
            let impact = byPhase[.impact]
        else {
            XCTFail("Missing key phases for late-downswing profile")
            return
        }

        XCTAssertGreaterThan(earlyDownswing, transition)
        XCTAssertLessThan(earlyDownswing, impact)
    }
}

@MainActor
private func makeSyntheticSwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.30, 0.72, 0.34, 0.72),
        (0.32, 0.71, 0.36, 0.71),
        (0.36, 0.67, 0.40, 0.67),
        (0.42, 0.58, 0.46, 0.58),
        (0.48, 0.46, 0.52, 0.46),
        (0.54, 0.34, 0.58, 0.34),
        (0.52, 0.39, 0.56, 0.39),
        (0.46, 0.50, 0.50, 0.50),
        (0.34, 0.70, 0.38, 0.70),
        (0.56, 0.28, 0.60, 0.28)
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY) = wrists
        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.leftShoulder, x: 0.40, y: 0.34),
                joint(.rightShoulder, x: 0.60, y: 0.34),
                joint(.leftHip, x: 0.44, y: 0.60),
                joint(.rightHip, x: 0.58, y: 0.60),
                joint(.leftWrist, x: leftWristX, y: leftWristY),
                joint(.rightWrist, x: rightWristX, y: rightWristY)
            ],
            confidence: 0.9
        )
    }
}

@MainActor
private func makeLateDownswingDriftFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.30, 0.72, 0.34, 0.72),
        (0.33, 0.68, 0.37, 0.68),
        (0.38, 0.60, 0.42, 0.60),
        (0.45, 0.49, 0.49, 0.49),
        (0.52, 0.36, 0.56, 0.36), // top
        (0.50, 0.40, 0.54, 0.40), // transition
        (0.48, 0.46, 0.52, 0.46),
        (0.44, 0.56, 0.48, 0.56), // early downswing candidate
        (0.39, 0.66, 0.43, 0.66), // impact neighborhood
        (0.56, 0.30, 0.60, 0.30)  // follow through
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY) = wrists
        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.leftShoulder, x: 0.40, y: 0.34),
                joint(.rightShoulder, x: 0.60, y: 0.34),
                joint(.leftHip, x: 0.44, y: 0.60),
                joint(.rightHip, x: 0.58, y: 0.60),
                joint(.leftWrist, x: leftWristX, y: leftWristY),
                joint(.rightWrist, x: rightWristX, y: rightWristY)
            ],
            confidence: 0.9
        )
    }
}

@MainActor
private func joint(_ name: SwingJointName, x: Double, y: Double, confidence: Double = 0.9) -> SwingJoint {
    SwingJoint(name: name, x: x, y: y, confidence: confidence)
}

@MainActor
private func makeFullAnchorSet() -> [HandAnchor] {
    [
        HandAnchor(phase: .address, x: 0.30, y: 0.72),
        HandAnchor(phase: .takeaway, x: 0.35, y: 0.68),
        HandAnchor(phase: .shaftParallel, x: 0.42, y: 0.56),
        HandAnchor(phase: .topOfBackswing, x: 0.52, y: 0.34),
        HandAnchor(phase: .transition, x: 0.50, y: 0.39),
        HandAnchor(phase: .earlyDownswing, x: 0.43, y: 0.50),
        HandAnchor(phase: .impact, x: 0.32, y: 0.70),
        HandAnchor(phase: .followThrough, x: 0.58, y: 0.26)
    ]
}

@MainActor
private func makeWorkflowRecord(
    keyframeValidationStatus: KeyframeValidationStatus,
    anchors: [HandAnchor],
    pathPoints: [PathPoint]
) -> SwingRecord {
    let filename = "workflow.mov"
    makePersistedGarageVideoFixture(named: filename)
    let frames = makeSyntheticSwingFrames()
    let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

    return SwingRecord(
        title: "Workflow Record",
        mediaFilename: filename,
        frameRate: 60,
        swingFrames: frames,
        keyFrames: keyFrames,
        keyframeValidationStatus: keyframeValidationStatus,
        handAnchors: anchors,
        pathPoints: pathPoints,
        analysisResult: AnalysisResult(
            issues: [],
            highlights: ["Workflow baseline"],
            summary: "Processed synthetic swing frames."
        )
    )
}

@MainActor
private func makePersistedGarageVideoFixture(named filename: String) {
    let fileManager = FileManager.default
    guard
        let baseURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    else {
        return
    }

    let garageURL = baseURL.appendingPathComponent("GarageSwingVideos", isDirectory: true)
    let fileURL = garageURL.appendingPathComponent(filename)

    if fileManager.fileExists(atPath: fileURL.path) {
        return
    }

    try? fileManager.createDirectory(at: garageURL, withIntermediateDirectories: true)
    fileManager.createFile(atPath: fileURL.path, contents: Data())
}
```

## File: `LIFE-IN-SYNCTests/LIFE_IN_SYNCTests.swift`

```swift
//
//  LIFE_IN_SYNCTests.swift
//  LIFE-IN-SYNCTests
//
//  Created by Colton Thomas on 3/31/26.
//

import Foundation
import Testing
@testable import LIFE_IN_SYNC

@MainActor
struct LIFE_IN_SYNCTests {
    @Test func habitModelStoresIdentityAndTarget() async throws {
        let habit = Habit(name: "Water", targetCount: 8)

        #expect(habit.name == "Water")
        #expect(habit.targetCount == 8)
        #expect(habit.id.uuidString.isEmpty == false)
    }

    @Test func taskModelDefaultsToOpenMediumPriority() async throws {
        let task = TaskItem(title: "Call bank")

        #expect(task.isCompleted == false)
        #expect(task.priority == TaskPriority.medium.rawValue)
        #expect(task.id.uuidString.isEmpty == false)
    }

    @Test func studyEntryStoresNotes() async throws {
        let entry = StudyEntry(title: "Morning Study", passageReference: "Psalm 1", notes: "Meditate on the contrast.")

        #expect(entry.title == "Morning Study")
        #expect(entry.passageReference == "Psalm 1")
        #expect(entry.notes == "Meditate on the contrast.")
    }

    @Test func swingRecordStoresOptionalMediaAndNotes() async throws {
        let record = SwingRecord(title: "Driver session", mediaFilename: "swing.mov", notes: "Ball started left.")

        #expect(record.mediaFilename == "swing.mov")
        #expect(record.notes == "Ball started left.")
    }

    @Test func garagePathGenerationIncludesEndpointsAndIntermediateSamples() async throws {
        let anchors = [
            HandAnchor(phase: .address, x: 0.30, y: 0.72),
            HandAnchor(phase: .takeaway, x: 0.35, y: 0.68),
            HandAnchor(phase: .shaftParallel, x: 0.42, y: 0.56),
            HandAnchor(phase: .topOfBackswing, x: 0.52, y: 0.34),
            HandAnchor(phase: .transition, x: 0.50, y: 0.39),
            HandAnchor(phase: .earlyDownswing, x: 0.43, y: 0.50),
            HandAnchor(phase: .impact, x: 0.32, y: 0.70),
            HandAnchor(phase: .followThrough, x: 0.58, y: 0.26)
        ]

        let points = GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)

        #expect(points.count == 29)
        #expect(points.first?.x == anchors.first?.x)
        #expect(points.first?.y == anchors.first?.y)
        #expect(points.last?.x == anchors.last?.x)
        #expect(points.last?.y == anchors.last?.y)
        #expect(points[5].x != 0.3675)
    }

    @Test func garageDeterministicHandPathSampleIDIsStableAcrossRepeatedGeneration() async throws {
        let timestamps: [Double] = [0.0, 0.016667, 0.033333, 0.1, 0.5, 1.25]

        let firstPass = timestamps.enumerated().map { index, timestamp in
            garageDeterministicHandPathSampleID(index: index, timestamp: timestamp)
        }
        let secondPass = timestamps.enumerated().map { index, timestamp in
            garageDeterministicHandPathSampleID(index: index, timestamp: timestamp)
        }

        #expect(firstPass == secondPass)
        #expect(Set(firstPass).count == firstPass.count)
    }

    @Test func garageKeyframeDetectionReturnsCanonicalPhaseOrder() async throws {
        let frames = makeSyntheticSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

        #expect(keyFrames.count == SwingPhase.allCases.count)
        #expect(keyFrames.map(\.phase) == SwingPhase.allCases)
        #expect(keyFrames.map(\.frameIndex) == keyFrames.map(\.frameIndex).sorted())
        #expect(keyFrames[5].frameIndex <= keyFrames[6].frameIndex)
        #expect(keyFrames[6].frameIndex <= keyFrames[7].frameIndex)
    }

    @Test func garageKeyframeDetectionSkipsQuietPrerollAndFindsAddressNearSwingStart() async throws {
        let frames = makePrerollSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

        #expect(keyFrames.first?.phase == .address)
        #expect((keyFrames.first?.frameIndex ?? -1) < (keyFrames[1].frameIndex))
    }

    @Test func garageKeyframeDetectionKeepsImpactDistinctFromEarlyDownswing() async throws {
        let frames = makeSyntheticSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

        let earlyDownswing = keyFrames.first(where: { $0.phase == .earlyDownswing })?.frameIndex ?? -1
        let impact = keyFrames.first(where: { $0.phase == .impact })?.frameIndex ?? -1
        #expect(impact > earlyDownswing)
    }

    @Test func garageKeyframeDetectionPlacesEarlyBackswingFramesCloserToTakeawayAndShaftParallel() async throws {
        let frames = makeSyntheticSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let takeaway = try #require(keyFrames.first(where: { $0.phase == .takeaway }))
        let shaftParallel = try #require(keyFrames.first(where: { $0.phase == .shaftParallel }))
        let top = try #require(keyFrames.first(where: { $0.phase == .topOfBackswing }))

        #expect(takeaway.frameIndex <= 2)
        #expect(shaftParallel.frameIndex <= 4)
        #expect(takeaway.frameIndex < shaftParallel.frameIndex)
        #expect(shaftParallel.frameIndex < top.frameIndex)
    }

    @Test func garageKeyframeDetectionKeepsTransitionNearTopReversal() async throws {
        let frames = makeSyntheticSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let top = try #require(keyFrames.first(where: { $0.phase == .topOfBackswing }))
        let transition = try #require(keyFrames.first(where: { $0.phase == .transition }))

        #expect(transition.frameIndex >= top.frameIndex + 1)
        #expect(transition.frameIndex <= top.frameIndex + 2)
    }

    @Test func garageKeyframeDetectionCarriesCanonicalDecodedFrameIdentity() async throws {
        let frames = makeSyntheticSwingFrames()
        let decodedFrameTimestamps = frames.map(\.timestamp)

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let top = try #require(keyFrames.first(where: { $0.phase == .topOfBackswing }))

        #expect(top.frameIndex == 6)
        #expect(decodedFrameTimestamps[top.frameIndex] == frames[top.frameIndex].timestamp)
    }

    @Test func garageKeyframeDetectionDoesNotUseLateFinishAsTopOfBackswing() async throws {
        let frames = makeLateFinishSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let top = keyFrames.first(where: { $0.phase == .topOfBackswing })?.frameIndex ?? -1
        let follow = keyFrames.first(where: { $0.phase == .followThrough })?.frameIndex ?? -1

        #expect(top <= 6)
        #expect(follow > top)
    }

    @Test func garageInsightsReportBecomesReadyWhenAnchorsAndPathExist() async throws {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let anchors = [
            HandAnchor(phase: .address, x: 0.30, y: 0.72),
            HandAnchor(phase: .takeaway, x: 0.35, y: 0.68),
            HandAnchor(phase: .shaftParallel, x: 0.42, y: 0.56),
            HandAnchor(phase: .topOfBackswing, x: 0.52, y: 0.34),
            HandAnchor(phase: .transition, x: 0.50, y: 0.39),
            HandAnchor(phase: .earlyDownswing, x: 0.43, y: 0.50),
            HandAnchor(phase: .impact, x: 0.32, y: 0.70),
            HandAnchor(phase: .followThrough, x: 0.58, y: 0.26)
        ]
        let pathPoints = GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)
        let record = SwingRecord(
            title: "7 Iron",
            frameRate: 60,
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .approved,
            handAnchors: anchors,
            pathPoints: pathPoints,
            analysisResult: AnalysisResult(
                issues: [],
                highlights: ["Synthetic baseline"],
                summary: "Processed synthetic swing frames."
            )
        )

        let report = GarageInsights.report(for: record)

        #expect(report.isReady)
        #expect(report.metrics.contains(where: { $0.title == "Tempo" }))
        #expect(report.metrics.contains(where: { $0.title == "Impact Return" }))
        #expect(report.metrics.contains(where: { $0.title == "Anchor Coverage" && $0.value == "100%" }))
        #expect(report.highlights.contains(where: { $0.contains("tempo profile") }))
    }

    @Test func garageWorkflowMarksAnchorsIncompleteUntilAllEightArePlaced() async throws {
        let record = makeWorkflowRecord(
            keyframeValidationStatus: .approved,
            anchors: Array(makeFullAnchorSet().prefix(5)),
            pathPoints: []
        )

        let progress = GarageWorkflow.progress(for: record)

        #expect(progress.stages.first(where: { $0.stage == .markAnchors })?.status == .incomplete)
        #expect(progress.nextAction.stage == .markAnchors)
    }

    @Test func garageWorkflowPrioritizesFlaggedKeyframesAsNeedsAttention() async throws {
        let record = makeWorkflowRecord(
            keyframeValidationStatus: .flagged,
            anchors: makeFullAnchorSet(),
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: makeFullAnchorSet(), samplesPerSegment: 4)
        )

        let progress = GarageWorkflow.progress(for: record)

        #expect(progress.stages.first(where: { $0.stage == .validateKeyframes })?.status == .needsAttention)
        #expect(progress.nextAction.stage == .validateKeyframes)
    }

    @Test func garageWorkflowBecomesFullyCompleteWhenAllStagesAreReady() async throws {
        let anchors = makeFullAnchorSet()
        let record = makeWorkflowRecord(
            keyframeValidationStatus: .approved,
            anchors: anchors,
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)
        )

        let progress = GarageWorkflow.progress(for: record)

        #expect(progress.completedCount == 4)
        #expect(progress.stages.allSatisfy { $0.status == .complete })
        #expect(progress.nextAction.title == "Workflow Complete")
    }

    @Test func garageReviewVideoResolverFallsBackToExportAssetWhenReviewMasterIsMissing() async throws {
        let exportFilename = "export-fallback.mp4"
        makePersistedGarageExportFixture(named: exportFilename)

        let record = SwingRecord(
            title: "Export Fallback",
            reviewMasterFilename: "missing-review.mov",
            exportAssetFilename: exportFilename,
            swingFrames: makeSyntheticSwingFrames(),
            keyFrames: GarageAnalysisPipeline.detectKeyFrames(from: makeSyntheticSwingFrames())
        )

        let resolvedVideo = try #require(GarageMediaStore.resolvedReviewVideo(for: record))

        #expect(resolvedVideo.origin == .exportStorage)
        #expect(resolvedVideo.url.lastPathComponent == exportFilename)
    }

    @Test func garageReviewVideoResolverUsesBookmarkWhenStoredFilenameFails() async throws {
        let bookmarkURL = FileManager.default.temporaryDirectory.appendingPathComponent("garage-bookmark-\(UUID().uuidString).mov")
        FileManager.default.createFile(atPath: bookmarkURL.path, contents: Data())

        let record = SwingRecord(
            title: "Bookmark Fallback",
            reviewMasterBookmark: GarageMediaStore.bookmarkData(for: bookmarkURL),
            swingFrames: makeSyntheticSwingFrames(),
            keyFrames: GarageAnalysisPipeline.detectKeyFrames(from: makeSyntheticSwingFrames())
        )

        let resolvedVideo = try #require(GarageMediaStore.resolvedReviewVideo(for: record))

        #expect(resolvedVideo.origin == .reviewMasterBookmark)
        #expect(resolvedVideo.url.lastPathComponent == bookmarkURL.lastPathComponent)
    }

    @Test func garageWorkflowTreatsPoseFallbackAsReviewReadyWhenFramesStillExist() async throws {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let anchors = GarageAnalysisPipeline.deriveHandAnchors(from: frames, keyFrames: keyFrames)
        let record = SwingRecord(
            title: "Pose Fallback",
            swingFrames: frames,
            keyFrames: keyFrames,
            keyframeValidationStatus: .approved,
            handAnchors: anchors,
            pathPoints: GarageAnalysisPipeline.generatePathPoints(from: anchors, samplesPerSegment: 4)
        )

        let progress = GarageWorkflow.progress(for: record)

        #expect(GarageMediaStore.reviewFrameSource(for: record) == .poseFallback)
        #expect(progress.stages.first(where: { $0.stage == .importVideo })?.status == .complete)
    }

    @Test func garageManualAnchorMergePreservesManualPointWhileRefreshingAutomaticAnchors() async throws {
        let frames = makeSyntheticSwingFrames()
        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let merged = GarageAnalysisPipeline.mergedHandAnchors(
            preserving: [
                HandAnchor(phase: .address, x: 0.11, y: 0.22, source: .manual)
            ],
            from: frames,
            keyFrames: keyFrames
        )

        let addressAnchor = try #require(merged.first(where: { $0.phase == .address }))
        let impactAnchor = try #require(merged.first(where: { $0.phase == .impact }))

        #expect(addressAnchor.x == 0.11)
        #expect(addressAnchor.y == 0.22)
        #expect(addressAnchor.source == .manual)
        #expect(impactAnchor.source == .automatic)
        #expect(merged.count == SwingPhase.allCases.count)
    }

    @Test func garageKeyframeDetectionChoosesStableAddressAfterNoisyPreroll() async throws {
        let frames = makeNoisyPrerollSwingFrames()

        let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)
        let address = try #require(keyFrames.first(where: { $0.phase == .address }))

        #expect(address.frameIndex >= 2)
        #expect(address.frameIndex < (keyFrames.first(where: { $0.phase == .takeaway })?.frameIndex ?? Int.max))
    }

}

@MainActor
private func makeSyntheticSwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.30, 0.72, 0.34, 0.72),
        (0.32, 0.71, 0.36, 0.71),
        (0.36, 0.67, 0.40, 0.67),
        (0.42, 0.58, 0.46, 0.58),
        (0.48, 0.46, 0.52, 0.46),
        (0.54, 0.34, 0.58, 0.34),
        (0.52, 0.39, 0.56, 0.39),
        (0.46, 0.50, 0.50, 0.50),
        (0.34, 0.70, 0.38, 0.70),
        (0.56, 0.28, 0.60, 0.28)
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY) = wrists
        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.leftShoulder, x: 0.40, y: 0.34),
                joint(.rightShoulder, x: 0.60, y: 0.34),
                joint(.leftHip, x: 0.44, y: 0.60),
                joint(.rightHip, x: 0.58, y: 0.60),
                joint(.leftWrist, x: leftWristX, y: leftWristY),
                joint(.rightWrist, x: rightWristX, y: rightWristY)
            ],
            confidence: 0.9
        )
    }
}

@MainActor
private func makePoorlyFramedSwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.44, 0.78, 0.47, 0.78),
        (0.45, 0.75, 0.48, 0.75),
        (0.47, 0.68, 0.50, 0.68),
        (0.49, 0.06, 0.52, 0.06),
        (0.50, 0.08, 0.53, 0.08),
        (0.49, 0.14, 0.52, 0.14),
        (0.50, 0.05, 0.53, 0.05)
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY) = wrists
        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.nose, x: 0.48, y: 0.40),
                joint(.leftShoulder, x: 0.44, y: 0.48),
                joint(.rightShoulder, x: 0.54, y: 0.48),
                joint(.leftHip, x: 0.46, y: 0.70),
                joint(.rightHip, x: 0.54, y: 0.70),
                joint(.leftAnkle, x: 0.46, y: 0.93),
                joint(.rightAnkle, x: 0.54, y: 0.93),
                joint(.leftWrist, x: leftWristX, y: leftWristY),
                joint(.rightWrist, x: rightWristX, y: rightWristY)
            ],
            confidence: 0.52
        )
    }
}

@MainActor
private func makeLateFinishSwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.30, 0.74, 0.34, 0.74),
        (0.32, 0.73, 0.36, 0.73),
        (0.35, 0.68, 0.39, 0.68),
        (0.40, 0.58, 0.44, 0.58),
        (0.45, 0.44, 0.49, 0.44),
        (0.50, 0.30, 0.54, 0.30),
        (0.48, 0.36, 0.52, 0.36),
        (0.42, 0.50, 0.46, 0.50),
        (0.36, 0.66, 0.40, 0.66),
        (0.54, 0.22, 0.58, 0.22)
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY) = wrists
        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.leftShoulder, x: 0.40, y: 0.34),
                joint(.rightShoulder, x: 0.60, y: 0.34),
                joint(.leftHip, x: 0.44, y: 0.60),
                joint(.rightHip, x: 0.58, y: 0.60),
                joint(.leftWrist, x: leftWristX, y: leftWristY),
                joint(.rightWrist, x: rightWristX, y: rightWristY)
            ],
            confidence: 0.9
        )
    }
}

@MainActor
private func makePrerollSwingFrames() -> [SwingFrame] {
    let wristPairs: [(Double, Double, Double, Double)] = [
        (0.30, 0.72, 0.34, 0.72),
        (0.30, 0.72, 0.34, 0.72),
        (0.30, 0.72, 0.34, 0.72),
        (0.32, 0.71, 0.36, 0.71),
        (0.36, 0.67, 0.40, 0.67),
        (0.42, 0.58, 0.46, 0.58),
        (0.48, 0.46, 0.52, 0.46),
        (0.54, 0.34, 0.58, 0.34),
        (0.52, 0.39, 0.56, 0.39),
        (0.46, 0.50, 0.50, 0.50),
        (0.34, 0.70, 0.38, 0.70),
        (0.56, 0.28, 0.60, 0.28)
    ]

    return wristPairs.enumerated().map { index, wrists in
        let (leftWristX, leftWristY, rightWristX, rightWristY) = wrists
        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.leftShoulder, x: 0.40, y: 0.34),
                joint(.rightShoulder, x: 0.60, y: 0.34),
                joint(.leftHip, x: 0.44, y: 0.60),
                joint(.rightHip, x: 0.58, y: 0.60),
                joint(.leftWrist, x: leftWristX, y: leftWristY),
                joint(.rightWrist, x: rightWristX, y: rightWristY)
            ],
            confidence: 0.9
        )
    }
}

@MainActor
private func makeNoisyPrerollSwingFrames() -> [SwingFrame] {
    let samples: [(Double, Double, Double, Double, Double)] = [
        (0.24, 0.48, 0.28, 0.48, 0.28),
        (0.26, 0.52, 0.30, 0.52, 0.35),
        (0.30, 0.73, 0.34, 0.73, 0.96),
        (0.31, 0.73, 0.35, 0.73, 0.97),
        (0.33, 0.71, 0.37, 0.71, 0.95),
        (0.39, 0.62, 0.43, 0.62, 0.95),
        (0.47, 0.48, 0.51, 0.48, 0.94),
        (0.54, 0.35, 0.58, 0.35, 0.93),
        (0.50, 0.40, 0.54, 0.40, 0.93),
        (0.38, 0.64, 0.42, 0.64, 0.92),
        (0.33, 0.72, 0.37, 0.72, 0.92),
        (0.57, 0.29, 0.61, 0.29, 0.92)
    ]

    return samples.enumerated().map { index, sample in
        let (leftWristX, leftWristY, rightWristX, rightWristY, confidence) = sample
        return SwingFrame(
            timestamp: Double(index) * 0.1,
            joints: [
                joint(.leftShoulder, x: 0.40, y: 0.34),
                joint(.rightShoulder, x: 0.60, y: 0.34),
                joint(.leftHip, x: 0.44, y: 0.60),
                joint(.rightHip, x: 0.58, y: 0.60),
                joint(.leftWrist, x: leftWristX, y: leftWristY, confidence: confidence),
                joint(.rightWrist, x: rightWristX, y: rightWristY, confidence: confidence)
            ],
            confidence: confidence
        )
    }
}

@MainActor
private func joint(_ name: SwingJointName, x: Double, y: Double, confidence: Double = 0.9) -> SwingJoint {
    SwingJoint(name: name, x: x, y: y, confidence: confidence)
}

@MainActor
private func makeFullAnchorSet() -> [HandAnchor] {
    [
        HandAnchor(phase: .address, x: 0.30, y: 0.72),
        HandAnchor(phase: .takeaway, x: 0.35, y: 0.68),
        HandAnchor(phase: .shaftParallel, x: 0.42, y: 0.56),
        HandAnchor(phase: .topOfBackswing, x: 0.52, y: 0.34),
        HandAnchor(phase: .transition, x: 0.50, y: 0.39),
        HandAnchor(phase: .earlyDownswing, x: 0.43, y: 0.50),
        HandAnchor(phase: .impact, x: 0.32, y: 0.70),
        HandAnchor(phase: .followThrough, x: 0.58, y: 0.26)
    ]
}

@MainActor
private func makeWorkflowRecord(
    keyframeValidationStatus: KeyframeValidationStatus,
    anchors: [HandAnchor],
    pathPoints: [PathPoint]
) -> SwingRecord {
    let filename = "workflow.mov"
    makePersistedGarageVideoFixture(named: filename)
    let frames = makeSyntheticSwingFrames()
    let keyFrames = GarageAnalysisPipeline.detectKeyFrames(from: frames)

    return SwingRecord(
        title: "Workflow Record",
        mediaFilename: filename,
        frameRate: 60,
        swingFrames: frames,
        keyFrames: keyFrames,
        keyframeValidationStatus: keyframeValidationStatus,
        handAnchors: anchors,
        pathPoints: pathPoints,
        analysisResult: AnalysisResult(
            issues: [],
            highlights: ["Workflow baseline"],
            summary: "Processed synthetic swing frames."
        )
    )
}


@MainActor
private func makePersistedGarageVideoFixture(named filename: String) {
    let fileManager = FileManager.default
    guard
        let baseURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    else {
        return
    }

    let garageURL = baseURL.appendingPathComponent("GarageSwingVideos", isDirectory: true)
    let fileURL = garageURL.appendingPathComponent(filename)

    if fileManager.fileExists(atPath: fileURL.path) {
        return
    }

    try? fileManager.createDirectory(at: garageURL, withIntermediateDirectories: true)
    fileManager.createFile(atPath: fileURL.path, contents: Data())
}

@MainActor
private func makePersistedGarageExportFixture(named filename: String) {
    let fileManager = FileManager.default
    guard
        let baseURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    else {
        return
    }

    let exportsURL = baseURL
        .appendingPathComponent("GarageSwingVideos", isDirectory: true)
        .appendingPathComponent("Exports", isDirectory: true)
    let fileURL = exportsURL.appendingPathComponent(filename)

    if fileManager.fileExists(atPath: fileURL.path) {
        return
    }

    try? fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
    fileManager.createFile(atPath: fileURL.path, contents: Data())
}
```

## File: `LIFE-IN-SYNCUITests/LIFE_IN_SYNCUITests.swift`

```swift
//
//  LIFE_IN_SYNCUITests.swift
//  LIFE-IN-SYNCUITests
//
//  Created by Colton Thomas on 3/31/26.
//

import XCTest

final class LIFE_IN_SYNCUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testModuleMenuShowsCanonicalModules() throws {
        let app = XCUIApplication()
        app.launchArguments.append("SKIP_LAUNCH_AFFIRMATION")
        app.launch()

        app.buttons["open-module-menu"].tap()

        let habitStackEntry = app.descendants(matching: .any)["module-menu-habitStack"]
        let taskProtocolEntry = app.descendants(matching: .any)["module-menu-taskProtocol"]
        let calendarEntry = app.descendants(matching: .any)["module-menu-calendar"]
        let supplyListEntry = app.descendants(matching: .any)["module-menu-supplyList"]

        XCTAssertTrue(app.navigationBars["Modules"].waitForExistence(timeout: 2))
        scrollToElementIfNeeded(supplyListEntry, in: app)

        XCTAssertTrue(habitStackEntry.waitForExistence(timeout: 2))
        XCTAssertTrue(taskProtocolEntry.exists)
        XCTAssertTrue(calendarEntry.exists)
        XCTAssertTrue(supplyListEntry.exists)
    }

    @MainActor
    func testDashboardNavigatesToCalendarFromDashboardRow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("SKIP_LAUNCH_AFFIRMATION")
        app.launch()

        app.buttons["dashboard-module-calendar"].tap()

        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["return-to-dashboard"].exists)
    }

    @MainActor
    func testDashboardShowsTodaySnapshotCards() throws {
        let app = XCUIApplication()
        app.launchArguments.append("SKIP_LAUNCH_AFFIRMATION")
        app.launch()

        let habitsCard = app.descendants(matching: .any)["dashboard-stat-habits"]
        let tasksCard = app.descendants(matching: .any)["dashboard-stat-tasks"]
        let eventsCard = app.descendants(matching: .any)["dashboard-stat-events"]
        let itemsCard = app.descendants(matching: .any)["dashboard-stat-items"]

        scrollToElementIfNeeded(habitsCard, in: app)

        XCTAssertTrue(habitsCard.waitForExistence(timeout: 2))
        XCTAssertTrue(tasksCard.exists)
        XCTAssertTrue(eventsCard.exists)
        XCTAssertTrue(itemsCard.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments.append("SKIP_LAUNCH_AFFIRMATION")
            app.launch()
        }
    }
}

private extension LIFE_IN_SYNCUITests {
    func scrollToElementIfNeeded(_ element: XCUIElement, in app: XCUIApplication, maxScrolls: Int = 6) {
        guard element.isHittable == false else { return }

        for _ in 0..<maxScrolls {
            app.swipeUp()

            if element.isHittable {
                return
            }

            _ = element.waitForExistence(timeout: 0.5)

            if element.isHittable {
                return
            }
        }

        XCTFail("Failed to scroll to a hittable element after \(maxScrolls) scrolls: \(element)")
    }
}
```

## File: `LIFE-IN-SYNCUITests/LIFE_IN_SYNCUITestsLaunchTests.swift`

```swift
//
//  LIFE_IN_SYNCUITestsLaunchTests.swift
//  LIFE-IN-SYNCUITests
//
//  Created by Colton Thomas on 3/31/26.
//

import XCTest

final class LIFE_IN_SYNCUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments.append("SKIP_LAUNCH_AFFIRMATION")
        app.launch()
        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

## File: `PRD.md`

```markdown
# Command Center - Personal Dashboard PRD

> **Deployment Status**: ✅ Ready for Production - All mock and sample data has been cleared. The app starts with a clean slate and includes a data reset feature in Settings for users who want to start fresh.

A comprehensive personal dashboard application that integrates habit tracking, financial management, task management, workout planning, AI coaching (Knox), shopping lists, calendar events, and golf swing analysis. The app features a neumorphic dark theme with glassmorphic elements, providing a modern and cohesive user experience across all modules.

**Experience Qualities**:
1. **Satisfying** - Each tap provides immediate visual feedback with icons filling up, creating a dopamine-rewarding experience
2. **Motivating** - Visual progress bars and celebration animations encourage users to complete their daily goals
3. **Simple** - No complex menus or settings—just set a goal, tap throughout the day, and watch progress
4. **Personalized** - Customizable theme options (light, dark, system) allow users to tailor the app's appearance to their preferences

**Complexity Level**: Light Application (focused feature set with visual feedback, daily state tracking, and cross-module completion analytics)
  - Habit tracking tool with visual icon-based progress, celebration animations, daily completion history, and a global completion tracking system for analytics across all modules

## Essential Features

### Loading Screen with Daily Affirmations
- **Functionality**: Display an animated loading screen with inspirational quotes or Bible verses while the app initializes, using AI to generate fresh content
- **Purpose**: Create positive user experience on app launch while masking load time, set motivational tone for the session
- **Trigger**: User opens or refreshes the app
- **Progression**: App loads → Loading screen appears with animated background → AI fetches daily affirmation → Quote/verse animates in with elegant typography → App content loads in background → Smooth fade transition to main interface
- **Success criteria**: Loading screen displays within 100ms, affirmation appears smoothly and remains visible for ~4 seconds to allow reading, transitions feel seamless, fallback quotes available if AI fails

### Visual Progress Tracking
- **Functionality**: Display a grid of icon representations (glasses for water, checkmarks for habits, etc.) that fill/highlight as user directly taps individual icons to log progress toward daily goal
- **Purpose**: Create satisfying visual feedback that motivates completion through seeing progress accumulate with direct icon interaction
- **Trigger**: User sets daily goal (e.g., "8 glasses of water")
- **Progression**: User opens app → Sees grid of 8 empty glass icons → Taps individual icons throughout day → Each tapped icon fills with animated color transition → Final icon triggers celebration animation → Completion logged to history
- **Success criteria**: Icons animate smoothly on tap (< 200ms), celebration fires on final completion, daily progress persists, clicking filled icons allows adjusting progress backwards

### Goal Setting
- **Functionality**: Simple interface to set habit name, choose icon type, and set daily target number
- **Purpose**: Allow users to customize tracking for different habit types (water, steps, pages read, etc.)
- **Trigger**: User taps "Add Habit" or edits existing habit
- **Progression**: Tap add habit → Enter habit name → Select icon type from preset options → Set target number (1-20) → Habit appears in list
- **Success criteria**: Changes save immediately, icon selection is intuitive, reasonable numeric limits prevent errors

### Celebration Animation
- **Functionality**: Confetti or particle animation with sound/haptic feedback when daily goal is completed
- **Purpose**: Provide dopamine reward for completing goal, reinforcing positive behavior
- **Trigger**: User completes final increment of daily goal by tapping the last empty icon
- **Progression**: User taps final empty icon → Icon fills → Screen-wide celebration animation plays → Success message appears → Completion recorded with timestamp
- **Success criteria**: Animation plays within 100ms of completion, feels rewarding without being excessive (2-3 seconds), doesn't block continued interaction

### History & Streaks
- **Functionality**: Calendar view showing which days goals were completed, current streak counter, completion analytics across all modules
- **Purpose**: Provide long-term motivation through streak building, visual history, and data-driven insights into completion patterns
- **Trigger**: User views history tab, sees streak badge on main screen, or accesses analytics dashboard
- **Progression**: User completes daily goal → Completion logged with date → Calendar marks day as complete → Streak counter increments if consecutive → Completion stats update → User can view past days and patterns across modules
- **Success criteria**: Streak calculates correctly across day boundaries, history persists indefinitely, missed days clearly visible, completion data can be analyzed across all modules

### Global Completion Tracking System
- **Functionality**: Unified system for tracking, separating, and analyzing completed vs. active items across all modules (Habits, Tasks, Workouts, etc.)
- **Purpose**: Provide consistent completion tracking, enable rich analytics, maintain data integrity, and allow cross-module insights
- **Trigger**: Any item completion in any module
- **Progression**: User completes item → Completion timestamp recorded → Item moved to completed list → Stats updated in real-time → Analytics data accumulated → User can filter by completion status and view statistics
- **Success criteria**: All modules use consistent completion tracking, active/completed items properly separated, statistics accurate, completion data persists, filters work correctly, analytics provide actionable insights

### AI Financial Advisor Interview & Budget Generation
- **Functionality**: Multi-step interview process where an AI financial advisor asks comprehensive questions about income, housing, debt, goals, and spending habits, then generates a detailed, personalized budget plan (currently uses Spark LLM, planned migration to Gemini Pro 2.5 for enhanced reasoning)
- **Purpose**: Provide in-depth financial planning through conversational AI guidance, creating optimized budget allocations based on user's complete financial picture
- **Trigger**: User navigates to Finance module → AI Financial Advisor tab
- **Progression**: User starts interview → Answer 5 step questionnaire covering income, housing, debt, goals, and spending habits → AI analyzes complete profile → Generates detailed budget with category allocations → Shows personalized recommendations with reasoning → Provides savings strategy → Offers debt payoff plan (if applicable) → Displays actionable steps
- **Success criteria**: Interview feels conversational and thorough, all financial factors considered, budget totals balance to income, recommendations are specific and practical, AI reasoning is clear and helpful, budget persists for future reference, user can restart process anytime

### AI Provider Integration (Planned)
- **Functionality**: Integrate Google Gemini Pro 2.5 alongside existing Spark LLM (GPT-4o) with intelligent routing, fallback mechanisms, and unified abstraction layer
- **Purpose**: Leverage best AI model for each task, optimize costs, improve reasoning capabilities for complex features, enable multimodal futures
- **Trigger**: Developer configures Gemini API key in settings (owner only)
- **Progression**: Owner adds API key → System validates configuration → AI router automatically selects optimal provider per feature → Usage tracked for cost optimization → Automatic fallback on failures → Analytics show provider performance
- **Success criteria**: Seamless provider switching, <3s response times, >99% uptime with fallback, secure key storage, no user-facing errors, cost tracking accurate, documentation complete

### Theme Personalization
- **Functionality**: Toggle between light, dark, and system-preferred themes with persistent storage of user preference
- **Purpose**: Provide visual customization that adapts to user environment and preference, enhancing comfort and accessibility
- **Trigger**: User clicks theme toggle button (top-right corner or in navigation drawer)
- **Progression**: User opens theme menu → Selects light, dark, or system theme → Interface transitions smoothly to selected theme → Preference saved automatically → Theme persists across sessions
- **Success criteria**: Theme changes apply instantly with smooth transitions, user preference persists between sessions, system theme automatically adapts to OS preference changes, all UI elements properly support both themes with correct contrast ratios

### Shopping List Module
- **Functionality**: Minimalist shopping list manager with add, edit, delete, and check/uncheck capabilities—just like pen and paper, but with beautiful digital polish
- **Purpose**: Provide a distraction-free shopping list experience that feels natural and effortless, like writing on a notepad
- **Trigger**: User navigates to Shopping module from navigation drawer
- **Progression**: User opens Shopping → Sees clean neumorphic notepad interface → Types item name and clicks Add → Item appears in list with checkbox → User checks off items while shopping → Checked items move to bottom with strikethrough → User can inline-edit any item name → User can delete items → Simple counter shows active vs completed items
- **Success criteria**: Interface feels like a physical notepad, add/edit/delete operations are instant with smooth animations, items persist between sessions using useKV, inline editing feels natural, completed items remain visible but visually de-emphasized, all interactions are polished with subtle hover states and satisfying micro-interactions

### Golf Swing Analyzer Module
- **Functionality**: Professional AI-powered golf swing analysis using pose estimation to extract 3D landmarks, compute critical metrics (spine angle, hip rotation, head movement, swing plane, tempo, weight transfer), and generate personalized feedback with drill recommendations. Supports large video files up to 500MB for high-quality analysis.
- **Purpose**: Provide golfers with instant, professional-grade swing analysis without expensive coaching sessions, enabling data-driven improvement through actionable insights
- **Trigger**: User navigates to Golf Swing module (formerly Vault) from navigation drawer
- **Progression**: User uploads swing video (MP4, MOV, AVI, etc. up to 500MB) → Video processes with real-time progress display (uploading → extracting frames → pose estimation → analyzing mechanics → generating AI insights) → Large files (>200MB) show extended processing notification → Completed analysis displays with video playback, detailed metrics dashboard, strengths/improvements breakdown, AI-generated insights, and personalized practice drills → User can upload multiple swings and compare progress over time → Historical analyses persist in sidebar for easy access
- **Success criteria**: Video upload accepts common formats under 500MB with informative feedback for large files, processing completes with accurate progress feedback, pose estimation detects key body landmarks reliably, metrics calculations are accurate and meaningful, AI feedback is specific and actionable, drill recommendations target actual weaknesses, interface is intuitive for non-technical users, all data persists between sessions, video playback is smooth, comparison view shows improvement trends

## Edge Case Handling
- **Empty States**: Show welcoming prompt "Start your first habit!" with animated icon when no habits exist; "Upload Your First Swing" for golf analyzer
- **Goal Already Complete**: Show success state when daily goal is reached; icons remain clickable to adjust progress
- **Date Boundaries**: Progress resets at midnight local time; completed days logged to history
- **Multiple Habits**: Support tracking multiple different habits simultaneously with separate progress for each
- **Accidental Taps**: Clicking filled icons adjusts progress backwards to that point, allowing easy corrections
- **Long Streaks**: Special milestone celebrations at 7, 30, 100 days with different animations
- **Data Loss Prevention**: Confirm before deleting habits; show toast with undo option
- **Theme Transitions**: Smooth color transitions when switching themes; no jarring flashes
- **System Theme Changes**: Automatically adapt when user changes OS theme preference (when system theme is selected)
- **Video Upload Errors**: Validate file type and size before processing, show clear error messages for unsupported formats or files exceeding 500MB limit with guidance to compress video
- **Large Video Files**: Files over 200MB show informative notification about extended processing time, graceful handling of memory constraints
- **Processing Failures**: Graceful error handling with retry option, error state persists in analysis list
- **Incomplete Analysis**: Partial results saved if analysis fails mid-process, user can delete and retry
- **No Video Selected**: File input validates selection before starting upload process
- **Browser Compatibility**: Video playback fallbacks for unsupported codecs, WebGL requirements checked for pose estimation

## Design Direction
The interface should evoke a premium, futuristic tech aesthetic inspired by Tesla Cybertruck's UI and high-end automotive dashboards—sophisticated, minimalist, and cutting-edge. The neumorphic (soft-UI) approach with dark backgrounds, subtle depth through shadows, and glowing cyan accents creates a tactile, three-dimensional interface that feels both tangible and futuristic. Every element should feel precisely crafted with purposeful micro-interactions, smooth physics-based animations, and attention to detail that reinforces premium quality.

## Color Selection
**Neumorphic Dark Palette with Electric Cyan Glow**: The design uses a dark neumorphic style with charcoal gray surfaces that create soft, raised or inset effects through dual-shadow techniques (light shadow from top-left, dark shadow from bottom-right). Vibrant electric cyan serves as the primary accent, providing a high-tech glow effect that stands out beautifully against dark backgrounds.

**Dark Neumorphic Theme:**
- **Primary Color**: Electric Cyan (oklch 0.68 0.19 211) - High-tech glow for active buttons, primary actions, progress rings, and interactive highlights; used with box-shadow glow effects
- **Secondary Colors**: 
  - Card Surface (oklch 0.26 0.01 240) - Raised neumorphic cards with dual shadow
  - Main Background (oklch 0.22 0.01 240) - Deep charcoal base
  - Elevated Elements (oklch 0.30 0.015 240) - Borders and lighter surfaces
- **Accent Color**: Electric Cyan with glow - Creates depth through 0 0 20px oklch(0.68 0.19 211 / 0.3) shadows for glowing buttons and active states
- **Foreground/Background Pairings**:
  - Background (Deep Charcoal oklch 0.22 0.01 240): Light Text (oklch 0.95 0.005 240) - Ratio 16.8:1 ✓
  - Card (Charcoal oklch 0.26 0.01 240): Light Text (oklch 0.95 0.005 240) - Ratio 14.2:1 ✓
  - Primary (Cyan oklch 0.68 0.19 211): White text (oklch 0.98 0.005 240) - Ratio 5.1:1 ✓
  - Secondary (Mid Charcoal oklch 0.30 0.015 240): Light text (oklch 0.90 0.01 240) - Ratio 8.4:1 ✓
  - Muted (Dark Gray oklch 0.28 0.01 240): Muted text (oklch 0.55 0.01 240) - Ratio 4.6:1 ✓

## Font Selection
Typography should convey technical precision and modern elegance through clean sans-serif fonts optimized for digital displays—Outfit for display/headings and Inter for body text, both with excellent legibility on dark backgrounds.

- **Typographic Hierarchy**:
  - H1 (Page Titles): Outfit Bold / 48px mobile, 80px desktop / tight letter spacing (-0.02em) / 1.1 line height / gradient text effect
  - H2 (Section Headers): Outfit SemiBold / 28px / tight (-0.01em) / 1.2
  - H3 (Widget Titles): Inter SemiBold / 14px / uppercase / wide spacing (0.05em) / muted color
  - H4 (Card Headers): Outfit Medium / 20px / normal / 1.3
  - Body (Descriptions): Inter Regular / 16px / normal / 1.5
  - Stats (Large Numbers): Outfit Bold / 64px / tight / 1.0 / tabular-nums / gradient effect
  - Data Labels: Inter Medium / 12px / uppercase / wide (0.08em) / 1.4 / muted color
  - Captions: Inter Regular / 14px / normal / 1.4
  - Metrics: Inter SemiBold / 18px / tabular-nums

## Animations
Animations should feel smooth, polished, and physics-based—like premium automotive interfaces. Transitions use spring-based easing for natural, satisfying motion. The balance is purposeful micro-interactions that delight without distracting, with hover states that respond instantly and state changes that feel tactile through subtle scale and glow effects.

- **Purposeful Meaning**: Spring-based animations communicate premium quality; cyan glow pulses indicate active/processing states; neumorphic depth changes (pressed/raised) provide tactile feedback; smooth fades maintain context during navigation
- **Hierarchy of Movement**: 
  - Primary: Button press depth changes (200ms spring), glow pulse on active elements (3s infinite), circular progress rings with smooth transitions
  - Secondary: Card hover elevation with 4px lift (300ms spring), page transitions with fade (400ms), drawer slide with spring physics
  - Tertiary: Icon color shifts (150ms ease), input focus glow (200ms), micro-scale on tap (100ms)

## Component Selection

- **Components**:
  - **NeumorphicCard**: Primary container with dual-shadow depth effect (raised or inset variants)
  - **Dialog**: Forms and modals with neumorphic styling and backdrop blur
  - **Progress**: Circular rings with cyan glow, linear bars with gradient fill
  - **Badge**: Pill-shaped indicators with subtle inset styling
  - **Tabs**: Segmented control with active state using glowing cyan button
  - **Input**: Inset neumorphic fields with focus glow effect
  - **Button**: Raised neumorphic (default) or glowing cyan (primary) variants with press depth animation
  - **ScrollArea**: Custom thin scrollbar with neumorphic track
  - **IconCircle**: 56px circular container with neumorphic depth, optional cyan glow for active state

- **Customizations**:
  - **Glowing Buttons**: Cyan background with box-shadow glow (0 0 20px cyan/0.4) that intensifies on hover
  - **Neumorphic Surfaces**: Dual-shadow technique (8px 8px 16px dark, -4px -4px 12px light) for raised effect
  - **Metric Display**: Extra-large numbers (64px+) with gradient cyan effect and tabular numerals
  - **Progress Rings**: SVG circular progress with cyan stroke, drop-shadow glow, and smooth transitions
  - **Mode Buttons**: 64px circular neumorphic buttons that transform to glowing cyan when active

- **States**:
  - **Buttons**: Default (raised neumorphic with dual shadow), Hover (slightly elevated, reduced shadow), Active (inset depth with inverted shadow), Glow Variant (cyan background with box-shadow glow)
  - **Cards**: Default (raised neumorphic), Hover (increased elevation with 4px lift, optional glow border), Active (subtle scale 0.98)
  - **Icon Circles**: Default (raised 56px circle), Hover (reduced shadow depth), Glow (cyan background with radial glow)

- **Icon Selection**:
  - Primary Icons: House (dashboard), CheckSquare (habits), CurrencyDollar (finance), ListChecks (tasks), Barbell (workouts), Brain (Knox AI)
  - All icons use Phosphor Icons with 'regular' weight by default, 'fill' weight for active states
  - Consistent 20-24px sizing for most contexts, 28px+ for primary navigation

- **Spacing**: 8-based scale with generous breathing room (16px, 24px, 32px, 48px) between cards; internal card padding of 24px-32px; icon circles with 12-16px spacing; min touch targets of 56px (icon circles) and 48px (buttons)

- **Mobile**: 
  - Full-width neumorphic cards with 16px horizontal margins
  - Large touch targets (56px+ icon circles, 48px+ buttons)
  - Bottom-anchored navigation with neumorphic FAB (80px)
  - Drawer navigation slides from left with backdrop blur
  - Reduced card padding (16px) and font sizes on mobile
  - Single column grid layout below 768px

## Accessibility & UX Improvements

### Chart Accessibility
All data visualizations include text-based alternatives via the `AccessibleChart` component:
- **Data Table Toggle**: Users can switch between visual charts and accessible data tables
- **Screen Reader Support**: Proper ARIA labels and semantic markup
- **Keyboard Navigation**: All chart controls are fully keyboard accessible
- **Format Options**: Custom column formatters for readable data display
- **Implementation**: Finance module's spending breakdown chart demonstrates the pattern

### Component Library Consolidation
Standardized card components to single source of truth:
- **Primary Component**: `NeumorphicCard` for all card-based UI elements
- **Features**: Hover effects, pressed states, inset variants, glow borders, optional animations
- **Deprecated**: Old `Card.tsx` component replaced with NeumorphicCard
- **Consistency**: Uniform neumorphic styling across all modules
- **Documentation**: See `COMPONENT_CONSOLIDATION.md` for migration guide

## AI Integration

### Dual Provider Architecture
The app supports two AI providers with intelligent routing and automatic fallback:

- **Spark LLM (GPT-4o)**: Built-in provider, no configuration needed, excellent for JSON and quick responses
- **Google Gemini 2.5**: Optional provider requiring API key, cost-effective for long context and complex reasoning

### AI Provider Router
- **Functionality**: Unified interface that routes AI requests to optimal provider based on task and user preferences
- **Purpose**: Maximize reliability through automatic fallback while optimizing for cost and performance
- **Features**:
  - Automatic provider selection based on task complexity
  - Seamless fallback if primary provider fails
  - User-configurable preferences (Automatic, Spark, or Gemini)
  - Usage tracking and cost monitoring
  - Support for both text and JSON generation

### Current AI Features
1. **Daily Affirmations** - Generated motivational quotes on app load (Spark LLM)
2. **AI Financial Advisor** - Multi-step interview and personalized budget generation (Can use either provider)
3. **Habit Suggestions** - AI-powered recommendations based on existing habits (Gemini recommended)
4. **Spending Analysis** - Pattern detection and financial insights (Gemini recommended)
5. **Workout Generation** - Custom workout plans based on fitness level and goals (Either provider)

### Settings & Configuration
- **Gemini API Key Management**: Secure storage in Spark KV, owner-only access
- **Connection Testing**: Verify API key validity before use
- **Provider Selection**: Choose default provider or let system auto-route
- **Usage Statistics**: Track requests, tokens, and costs per provider
- **AI Provider Badges**: Visual indicators showing which AI powered each feature

### Implementation Details
- **Location**: `/src/lib/ai/` and `/src/lib/gemini/`
- **Key Files**:
  - `ai/provider.ts` - Main AI router with fallback logic
  - `ai/usage-tracker.ts` - Cost and usage monitoring
  - `gemini/client.ts` - Gemini API wrapper
  - `ai/examples.ts` - Pre-built helper functions
- **Components**: AIBadge for provider indication, AccessibleChart for data viz
- **Module**: Settings page for configuration (owner-only)

### Security Considerations
- API keys stored encrypted in Spark KV store
- Never exposed in client code or logs
- Owner-only access to configuration
- Secure key masking in UI
- Error messages don't leak sensitive info
```

## File: `README.md`

```markdown
# LIFE-IN-SYNC

This repository has one real working copy on disk:

- Canonical path: `/Users/colton/Desktop/LIFE-IN-SYNC`

This is the actual repository folder on Desktop, not a symlink.

## Sync Model

Use GitHub as the source of truth between devices.

- Mac: work in `/Users/colton/Desktop/LIFE-IN-SYNC`
- iPhone: use Working Copy or another Git-capable app connected to the GitHub repo
- GitHub: shared remote used to move changes between devices

Do not use iCloud Drive as a second repo copy or as the editing path for this project.

## Daily Workflow

1. Open the repo from `/Users/colton/Desktop/LIFE-IN-SYNC`
2. Run `scripts/repo-health.sh`
3. Pull before starting work
4. Make changes on the branch you intend to use
5. Push before switching devices
6. Merge feature branches before expecting `main` to match everywhere

## Branch Rules

- `main` is the stable shared branch
- Short-lived feature branches are allowed
- If GitHub looks different from local code, check the current branch first

More detail lives in [docs/REPO_SYNC_WORKFLOW.md](docs/REPO_SYNC_WORKFLOW.md).
```

## File: `docs/AGENT_GUARDRAILS.md`

```markdown
# Agent Guardrails

## Purpose
This file defines how coding and planning agents must interpret the product.

Read `docs/CANONICAL_PRODUCT_SPEC.md` first before proposing features, architecture, models, or UI structure.

## Mandatory Rules
- Do not invent new top-level modules.
- Do not rename canonical modules unless the canonical spec is updated.
- Do not treat `PRD.md` as the source of truth when it conflicts with the canonical spec.
- Do not treat `life-in-sync-source.txt` as a migration requirement.
- Do not add login, cloud sync, or collaboration to v1 unless explicitly requested and the canonical spec is updated.
- Do not make AI autonomous.
- Do not allow AI to silently write user data.
- Do not merge module responsibilities for convenience.
- Do not expand Supply List into pantry or inventory management.
- Do not expand Task Protocol into full project management.
- Do not expand Garage into unsupported biomechanics claims or real-time coaching promises.

## Required Assumptions
- The app is native SwiftUI, not a web port.
- The app is local-first in v1.
- The dashboard is the root home.
- Module switching is shell-level navigation.
- Every module must preserve its own domain boundaries.

## When There Is Ambiguity
Use this decision order:
1. Follow `docs/CANONICAL_PRODUCT_SPEC.md`
2. Follow `ARCHITECTURE.md`
3. Follow the supporting docs in `docs/`
4. Ignore conflicting material from `PRD.md` or `life-in-sync-source.txt`

If ambiguity remains, ask for clarification instead of inventing behavior.

## Documentation Discipline
Before proposing implementation, verify:
- the feature belongs to a canonical module
- the feature is in v1 scope or explicitly marked deferred
- the behavior does not violate AI or boundary rules

If any of those checks fail, stop and call out the conflict.
```

## File: `docs/CANONICAL_PRODUCT_SPEC.md`

```markdown
# LIFE IN SYNC Canonical Product Spec

## Status
This document is the single source of truth for the product scope of the native app.

If any document conflicts with this file, this file wins.

## Product Definition
LIFE IN SYNC is a native SwiftUI personal life operating system for one user on one device.

It is a local-first app with a shared shell and distinct modules for specific life domains.

## Platform Definition
- Primary target: iPhone
- Technology direction: SwiftUI + SwiftData
- Persistence direction: local-first
- Connectivity expectation: offline-first for all non-AI features
- Account requirement in v1: none

## Canonical App Structure
The app consists of:
- one root app entry
- one shared shell
- one dashboard home
- one module menu
- eight modules

## Canonical Modules
These names are fixed and should be used consistently in documentation and code:
- Dashboard
- Capital Core
- Iron Temple
- Garage
- Habit Stack
- Task Protocol
- Calendar
- Bible Study
- Supply List

No additional top-level modules are part of the product truth for v1.

## What The App Is
The app is:
- a personal organization system
- a modular daily operating system
- a local record of the user’s habits, tasks, plans, finances, workouts, study, shopping, and golf practice

The app is not:
- a social platform
- a collaborative workspace
- a cloud-first service
- an autonomous AI agent
- a medical, financial, or theological authority

## Shell Truth
The shell owns:
- dashboard home
- top-level module switching
- stable app-wide navigation structure
- module entry points and summaries

The shell does not own:
- module business logic
- deep module workflows
- universal cross-module tabs

## Module Truth

### Capital Core
Owns:
- expenses
- categories
- budget targets
- financial snapshots

Does not own:
- shopping list ownership
- task ownership
- event ownership

### Iron Temple
Owns:
- workout templates
- workout sessions
- workout history

Does not own:
- general habits
- medical guidance
- nutrition platform depth

### Garage
Owns:
- golf swing records
- swing media references
- swing notes
- review history

Does not own:
- generic media library scope
- unsupported biomechanics certainty
- real-time coaching guarantees

### Habit Stack
Owns:
- recurring habits
- progress counts
- streaks
- timer-based habit sessions

Does not own:
- one-off tasks
- workouts as a full training system
- calendar ownership

### Task Protocol
Owns:
- one-time tasks
- task priority
- due dates
- completion state

Does not own:
- recurrence systems
- broad project management depth
- event ownership

### Calendar
Owns:
- events
- scheduled blocks
- agenda views
- date-based planning surfaces

Does not own:
- primary task ownership
- habit ownership
- journaling platform scope

### Bible Study
Owns:
- study entries
- passages
- notes
- study history

Does not own:
- theology authority claims
- generic life coaching outside scripture study

### Supply List
Owns:
- shopping items
- categories
- purchased state

Does not own:
- budgeting ownership
- inventory or pantry systems

## V1 Scope
V1 must include:
- a working shell
- a dashboard
- navigation to every module
- local persistence
- usable first-pass flows in every module

V1 depth is highest for:
- Habit Stack
- Task Protocol
- Calendar
- Supply List

V1 baseline depth is required for:
- Capital Core
- Iron Temple
- Bible Study
- Garage

## V1 Minimum User Flows

### Dashboard
- open app
- see today-oriented summary
- enter any module

### Habit Stack
- create habit
- log progress
- view streak or recent completion

### Task Protocol
- create task
- complete task
- filter by open or completed state

### Calendar
- create event
- view day agenda

### Supply List
- create shopping items
- group by category
- mark purchased

### Capital Core
- add expense
- categorize expense
- view current-period summary

### Iron Temple
- create workout template
- log workout session
- review recent sessions

### Bible Study
- create study entry
- save notes
- review prior entries

### Garage
- register or import swing record
- attach tags or notes
- review swing history

## Explicit V1 Exclusions
These are out of scope unless this file is updated:
- login or account systems
- cloud sync
- collaboration
- full project management
- pantry or inventory management
- advanced nutrition systems
- autonomous AI actions
- silent AI writes
- guaranteed real-time golf coaching
- advanced biomechanics claims

## AI Truth
AI is optional and advisory.

AI may:
- generate affirmations
- suggest categories, plans, or summaries
- help the user think

AI may not:
- silently create, update, or delete user records
- present speculation as authoritative truth
- bypass explicit user confirmation

## Cross-Module Truth
Allowed:
- dashboard to module entry
- task deadline into calendar context
- calendar item back to related task context

Disallowed by default:
- arbitrary deep links between unrelated modules
- shared global tabs across all modules
- moving ownership of one domain into another module for convenience

## Source Hierarchy
Use documents in this order:
1. `docs/CANONICAL_PRODUCT_SPEC.md`
2. `ARCHITECTURE.md`
3. files in `docs/`
4. `PRD.md`
5. `life-in-sync-source.txt`

If lower-priority material conflicts with higher-priority material, ignore the lower-priority material.

## Change Control
Any change to:
- top-level modules
- v1 scope
- ownership boundaries
- AI behavior rules
- local-first policy

must be made in this file first before code or secondary docs are updated.
```

## File: `docs/CI_IOS_RUNNER_SETUP.md`

```markdown
# iOS CI Runner Setup (Self-Hosted macOS)

## Purpose
This guide documents a production-ready baseline for running iOS CI jobs on a self-hosted GitHub Actions runner.

## 1) Hardware and OS Baseline
- Use a **Mac mini** (preferred) or a dedicated spare Mac.
- **Apple Silicon is recommended** for better Xcode and simulator performance.
- Use a supported macOS release compatible with your target Xcode version.
- Keep this machine dedicated to CI workloads to reduce drift and local user impact.

## 2) Install Xcode and Run First-Time Setup
1. Install Xcode from the Mac App Store (or Apple Developer downloads if pinning a specific version).
2. Point the active developer directory if needed:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
3. Accept the Xcode license:
   ```bash
   sudo xcodebuild -license accept
   ```
4. Run first-launch setup:
   ```bash
   sudo xcodebuild -runFirstLaunch
   ```
5. Install simulator runtimes needed by your CI matrix from Xcode settings.

## 3) Install GitHub Self-Hosted Runner
1. In GitHub, open the target repository (or organization):
   - **Settings → Actions → Runners → New self-hosted runner**
2. Choose **macOS** and follow GitHub's download/configuration commands on the Mac.
3. Configure runner labels to include:
   - `self-hosted`
   - `macOS`
   - `ios`
4. Validate registration appears in GitHub as online.

## 4) Enable Auto-Start with launchd
After configuring the runner in its install directory:

```bash
./svc.sh install
./svc.sh start
```

Useful operations:

```bash
./svc.sh status
./svc.sh stop
./svc.sh uninstall
```

This ensures the runner starts automatically after reboot.

## 5) Required Tool Checks
Run and verify both commands on the runner host:

```bash
xcodebuild -version
xcrun simctl list devices
```

Expected outcome:
- `xcodebuild -version` prints the expected Xcode and build version.
- `xcrun simctl list devices` returns available simulator devices (including runtime states).

## 6) Signing Guidance
### Simulator-only builds/tests
- If workflows only build and test on simulators, **signing secrets are not required**.

### Device builds, archive, and distribution
- For physical device testing, archive, TestFlight, or App Store delivery, signing setup is required.
- Recommended approaches:
  1. **Fastlane Match** for centralized certificate/profile management.
  2. **Manual keychain + provisioning profile setup** on the runner host.
- Protect all signing assets with least privilege and auditable access.

## 7) Security and Maintenance Notes
- Scope runner registration to the **smallest required boundary** (repo vs org) using least privilege.
- Use a **dedicated macOS user account** for the runner service.
- Keep macOS and Xcode patched on a regular schedule.
- Periodically clean derived data, stale simulators, and unused toolchains to reduce CI instability and disk pressure.
```

## File: `docs/DATA_AND_PERSISTENCE.md`

```markdown
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
```

## File: `docs/EXTERNAL_REPO_REPORT_TRANSLATION.md`

```markdown
# External Report Translation: `colton615-coder/life-in-sync` → LIFE IN SYNC (SwiftUI)

## Context
This assessment reviews the upstream web repository (`colton615-coder/life-in-sync`) and identifies what is valuable to reuse in this native SwiftUI codebase.

Because the upstream app was generated and iterated in a web stack (Next.js/TypeScript + Vercel + Supabase assumptions + AI-heavy UX language), this document translates the useful patterns into SwiftUI/SwiftData-compatible product language.

## Quick Verdict
You should **reuse the strategic architecture language and decision frameworks**, not the web implementation details.

High-value reusable assets from the upstream report/specs are:
- strong module-boundary language (ownership and non-ownership)
- failure-mode-first thinking (offline queueing, graceful degradation)
- proactive analytics patterns (predictive metrics, threshold alerts)
- explicit critique framework (shortcomings → concepts → selected concept)
- auditable quality checklist categories (security, performance, a11y, maintainability)

Low-value or non-portable assets are:
- React/DOM-specific implementation notes
- Vercel/PWA/browser APIs
- prompt-heavy persona copy that overstates capability

## What To Copy (and Why)

### 1) The "Shortcomings → Concepts → Selection" report structure
From `specs/finance_v3_design.md`, the upstream spec uses a strong pattern:
1. Identify concrete flaws in current architecture
2. Generate competing concept directions
3. Choose one concept with explicit rationale

Why this is valuable for your report:
- turns subjective product debate into a repeatable decision method
- gives reviewers confidence that alternatives were considered
- fits Swift feature planning well (RFC-like)

SwiftUI translation:
- Keep this exact report scaffold in module design docs
- Replace web file references (`Finance.tsx`) with native surfaces (`CapitalCoreView`, view models, SwiftData entities)

### 2) Predictive finance metrics (Burn Rate + Runway)
The upstream finance spec proposes two concrete metrics:
- Burn Rate (rolling daily spend)
- Runway (liquid assets / burn rate)

Why this is valuable:
- creates actionable financial awareness, not just ledger history
- maps cleanly to local-first computed properties in SwiftData

SwiftUI translation:
- `CapitalCoreViewModel` computes rolling 7/30-day burn rate
- `RunwayStatus` enum drives color + messaging (`critical`, `watch`, `healthy`)
- snapshot cards in Swift Charts with trend context

### 3) Offline-first queueing behavior
The upstream spec's local-first sync queue and optimistic UI pattern is directionally excellent even though implementation is web-specific (`idb`, service worker).

Why this is valuable:
- aligns with your canonical local-first app definition
- protects data capture under poor connectivity

SwiftUI translation:
- **v1 (no cloud/remote sync):** treat this as local intent journaling only. Persist intent immediately in SwiftData with a simple status field (e.g. `pending`, `applied`, `failed`) to support optimistic UI and local reconciliation.
- **Post‑v1 optional pattern:** if you later add an optional remote backup/sync target, reuse the same status field to drive a background flush (`BackgroundTasks` + reachability checks) to that remote. This is explicitly out of scope for v1.
- In all cases, UI can show a lightweight “pending” badge/icon for locally queued changes without blocking user flow.

### 4) Proactive, structured interventions (not just chat)
A key upstream contribution is shifting from reactive chatbot replies to structured intervention cards (e.g., budget reallocation proposal).

Why this is valuable:
- improves trust and usability vs free-form chat-only experiences
- easier to test and validate in native UI

SwiftUI translation:
- Use deterministic cards/actions first, LLM narrative second
- Example: `BudgetReallocationSuggestionCard` with explicit approve/reject actions
- Keep language concise and operational (avoid hype voice)

### 5) Audit taxonomy as a quality gate
`docs/COMPREHENSIVE_AUDIT.md` may overstate findings, but its category framing is useful:
- security
- performance
- accessibility
- logic correctness
- maintainability

Why this is valuable:
- gives you a reusable QA rubric for every module milestone
- can become Definition-of-Done checklist in your roadmap

SwiftUI translation:
- Security: keychain for secrets, no raw key storage in UserDefaults
- Performance: list virtualization strategy, lazy stacks, instrument traces
- A11y: Dynamic Type, VoiceOver labels, contrast checks
- Maintainability: module-level view model boundaries, shared UI primitives

## What NOT To Copy Directly

### 1) Web/PWA mechanics
Do not carry over:
- `window.launchQueue`
- IndexedDB APIs (`idb`)
- DOM-rendering-specific libraries and conventions
- Vercel deployment assumptions

Native substitute:
- UIDocumentPicker / fileImporter
- SwiftData persistence
- BackgroundTasks + URLSession as needed

### 2) Overconfident AI persona language
The upstream report/spec language (e.g., "brutal truth engine") is brand-flavored but can create product risk if copied into implementation requirements.

Native substitute:
- capability statements should be measurable and testable
- avoid anthropomorphic claims in functional specs

### 3) Direct security findings without validation
The audit lists many issues, but copy only the **risk categories**, not the exact issue counts or severities, unless independently reproduced in your native code.

## Ready-to-Use Insertions for Your Current Report

Use these sections almost verbatim in your Swift report:

### A. Decision Framework Section
"Each module proposal must include: (1) shortcomings analysis of current state, (2) at least two alternative concepts, and (3) explicit concept selection rationale tied to v1 constraints."

### B. Finance Intelligence Section
"Capital Core evolves from retrospective expense tracking to predictive cash-flow guidance by introducing rolling burn-rate and runway metrics, with threshold-driven interventions."

### C. Reliability Section
"All user-critical actions are captured as local intents first and reconciled later; connectivity affects sync latency, not data capture."

### D. Interaction Section
"The app prioritizes structured, testable action cards over free-form AI outputs for financial decisions and risk mitigation."

### E. QA Gate Section
"Release readiness is evaluated across five axes: security, performance, accessibility, logic correctness, and maintainability, with per-module evidence."

## Swift/SwiftUI Implementation Mapping (Suggested)

- `CapitalCoreView.swift`: add predictive summary cards + runway status indicator
- `FinancialSnapshot.swift` (Capital Core model, alongside `ExpenseRecord`/`BudgetRecord`): add `liquidAssets`, `burnRateSnapshot`, `syncStatus`
- new `CapitalCoreViewModel.swift`: compute rolling metrics and intervention triggers
- shared UI: reusable `StatusMetricCard`, `SuggestionCard`, and `PendingSyncBadge`

## Priority Recommendations
1. **Immediate**: Adopt the decision framework + QA taxonomy in your report language.
2. **Near-term**: Add predictive metrics (burn rate/runway) to Capital Core scope narrative.
3. **Mid-term**: Formalize local-intent/offline-sync state model in architecture docs.
4. **Optional**: Keep any AI persona language in marketing copy only, not functional requirements.

## Source Pointers Reviewed
- `README.md` (upstream framing and module claims)
- `specs/finance_v3_design.md` (best concrete architecture/report pattern)
- `docs/COMPREHENSIVE_AUDIT.md` (useful quality taxonomy, noisy severity values)
- `specs/FILE_HANDLING_API.md` (example of web-specific content to avoid direct port)
```

## File: `docs/GARAGE_UX_UI_AUDIT_IMPLEMENTATION_PLAN.md`

```markdown
# Garage Module UX/UI Audit — Spec + Implementation Plan

## Context
This plan converts the Garage UX/UI audit into an implementable engineering spec for the existing SwiftUI architecture. It is based on current code behavior in `GarageView`, shared module scaffolding in `SharedModuleUI`, and keyframe detection logic in `GarageAnalysis`.

## Current-State Findings (Code-Verified)

### 1) Entry/import flow has extra steps and a confirmation gate
- `GarageView` presents `AddSwingRecordSheet` before importing media, which creates an intermediate "New Swing Record" screen.  
- The sheet requires explicit Save after picking a video (`Save` toolbar button), rather than auto-import.  
- Picker is already filtered to `.videos`, which aligns with the audit requirement.

### 2) Garage screen inherits command-center cards and non-essential review chrome
- `GarageView` is hosted in `ModuleHubScaffold`, which always renders:
  - Command Center hero
  - Current State card
  - Next Attention card
- `GarageReviewTab` includes a `Details` sheet and supporting “Swing Details” UI that adds non-analysis chrome.

### 3) Review surface is split video + controls; not immersive-first
- `GarageFocusedReviewWorkspace` uses a side-by-side composition with frame surface and extensive right-pane UI.
- Visual overlays always draw sampled skeleton/wrist lines for current frame when frame data exists.
- Pose fallback mode intentionally draws reconstruction UI and explanatory labels.

### 4) Checkpoint timing and tracking concerns map to deterministic pipeline heuristics
- Early Downswing is derived by distance interpolation from transition→impact; this can drift later than expected in some swings.
- Manual correction exists today (adjust phase frame + hand anchor), but UX discoverability and per-point override coverage can be improved.

### 5) Status pills can truncate under tight width
- Multiple status chips use capsule text without explicit minimum scale factor or overflow handling.

---

## Product Spec (Target Behavior)

## A. Entry & Import Logic
### A1. Direct media-first flow (no intermediate form before import)
**Requirement**
- Tapping “Add Swing Record” should immediately open the iOS media picker.
- Picker only allows videos.
- On selection, import + analysis begins automatically.
- No final confirmation step for import.

**Implementation shape (low-blast-radius)**
1. Replace `AddSwingRecordSheet` as the primary entry flow with an inline importer controller/state in `GarageView` (or a dedicated lightweight import sheet that auto-runs import on selection and dismisses itself).
2. Preserve optional metadata editing as post-import action (e.g., rename/notes from review context), not pre-import blocker.
3. Keep `.photosPicker(... matching: .videos ...)` as-is for media filtering.

**Acceptance criteria**
- Add button → picker opens in one interaction.
- Selecting a video starts progress immediately.
- Record appears and review tab auto-selects after analysis completes.
- No explicit Save tap required to create record.

## B. Dashboard & Interface Cleanup
### B1. Garage-specific scaffold mode: minimal review shell
**Requirement**
- Remove Garage command-center aesthetic clutter:
  - Command Center hero
  - Current State / Next Attention cards
  - related card actions
- De-emphasize card-based “My Swing in Two” style layouts.
- Prioritize full-screen analysis video.

**Implementation shape**
1. Extend `ModuleHubScaffold` with configuration flags (or a display mode enum) so Garage can disable hero/status blocks while preserving tab infrastructure for other modules.
2. In Garage review tab, remove `Details` button/sheet from primary review UI.
3. Collapse overview-style cards for Garage into compact actions or route users directly to Records/Review.

**Acceptance criteria**
- Garage screen renders without hero/current/next cards.
- Review experience launches directly into analysis surface, not card stack.
- No visible “Details” tab/button in primary review workflow.

## C. Analysis & Scrubbing Precision
### C1. Raw-frame-first scrubbing
**Requirement**
- During scrubbing, raw video frames must be visible without sampled pose skeleton overlays.

**Implementation shape**
1. Add overlay mode state in `GarageFocusedReviewWorkspace`:
   - `.none` (default for scrubbing)
   - `.anchorOnly`
   - `.diagnosticPose` (optional/debug)
2. In `GarageReviewFrameOverlayCanvas`, gate skeleton/wrist rendering behind mode; keep anchor marker available.
3. In pose-fallback mode (no video available), keep fallback rendering but explicitly indicate reduced precision.

**Acceptance criteria**
- When video frame exists, skeleton lines/pose dots are not shown by default while scrubbing.
- Anchor marker remains visible/editable.

### C2. Tracking pinpoint and manual override completeness
**Requirement**
- Improve hand/grip auto-point reliability and guarantee user override for all automated points.

**Implementation shape**
1. Expand manual override model from selected phase only to any phase via checkpoint strip selection + adjust action (mostly already present; tighten UX and persistence guarantees).
2. Ensure manual anchor source is preserved through recomputation/merging.
3. Add confidence-aware visual hinting (low-confidence auto points subtly marked, never blocking manual edit).

**Acceptance criteria**
- Every checkpoint can be manually re-framed and re-anchored.
- Saved manual points remain stable after reload and subsequent status changes.

### C3. Checkpoint alignment correction (Early Downswing drift)
**Requirement**
- Correct phase synchronization so “Early Downswing” does not appear post-impact.

**Implementation shape**
1. Tighten temporal constraints in `GarageAnalysisPipeline`:
   - Enforce strict ordering: `transition < earlyDownswing < impact`.
   - Add max-distance-to-impact and pre-impact velocity sign checks.
2. Add deterministic fallback when heuristics conflict:
   - choose earliest candidate satisfying both ordering and downswing directionality.
3. Add regression tests with representative frame fixtures for late-trigger scenarios.

**Acceptance criteria**
- Early Downswing index always `< impactIndex`.
- Regression fixtures pass and no phase order inversions occur.

## D. Visual Polish
### D1. Status pill truncation hardening
**Requirement**
- Approved/Flagged/Pending pills should never clip/truncate awkwardly.

**Implementation shape**
1. Update pill views (`GarageCheckpointStatusBadge`, `GarageReviewStatusPill`, summary pills) with:
   - `.lineLimit(1)`
   - `.minimumScaleFactor(0.85)` where needed
   - adaptive horizontal padding and optional icon-first compact mode
2. In tight horizontal layouts, allow wrap to second row or switch to icon-only summary with accessibility label.

**Acceptance criteria**
- No truncation on iPhone SE width class and split view compact widths.

---

## Technical Plan by Milestone

## Milestone 1 — Import Workflow Refactor (highest impact)
- Remove Save-gated pre-import flow.
- Trigger picker directly from Add Swing Record.
- Auto-import immediately after video pick.
- Preserve robust progress/error overlays.

**Files likely touched**
- `LIFE-IN-SYNC/GarageView.swift`

## Milestone 2 — Garage Minimal Shell
- Add Garage-specific scaffold configuration (hide hero/current/next).
- Remove review details sheet from primary path.
- Keep tabs only if they remain useful; otherwise bias to Records + Review.

**Files likely touched**
- `LIFE-IN-SYNC/SharedModuleUI.swift`
- `LIFE-IN-SYNC/GarageView.swift`

## Milestone 3 — Precision Review Surface
- Introduce overlay mode + raw-frame default.
- Ensure anchor-only editing remains first-class.
- Keep fallback visuals only when no video frame exists.

**Files likely touched**
- `LIFE-IN-SYNC/GarageView.swift`

## Milestone 4 — Keyframe Alignment Fix + Tests
- Refine early-downswing heuristic.
- Add deterministic regression tests for phase ordering and known drift cases.

**Files likely touched**
- `LIFE-IN-SYNC/GarageAnalysis.swift`
- `LIFE-IN-SYNCTests/GarageDerivedReportsXCTests.swift` (or new targeted Garage keyframe tests)

## Milestone 5 — Visual Polish Pass
- Harden all Garage pills/chips against clipping.
- Validate compact width behavior.

**Files likely touched**
- `LIFE-IN-SYNC/GarageView.swift`

---

## Test and Validation Strategy

## Automated
1. **Pipeline unit tests**
   - Early Downswing before Impact invariant.
   - Ordered keyframe monotonicity across all phases.
2. **UI state tests (where available)**
   - Add Swing Record opens picker immediately.
   - Auto-import creates record without Save interaction.
3. **Snapshot/visual checks (if present)**
   - Compact width status pills are readable/no truncation.

## Manual QA checklist
- Import path from Add button is one-step into picker.
- Selecting a video immediately starts import.
- Review opens with raw frame visible while scrubbing.
- Manual checkpoint frame + hand-anchor override works for every phase.
- Early Downswing appears pre-impact on challenging clips.
- No command-center hero/current/next cards in Garage.

---

## Risks and Mitigations
- **Risk:** Removing pre-import form may reduce metadata capture.
  - **Mitigation:** Provide post-import rename/notes edit affordance.
- **Risk:** Shared scaffold changes could affect other modules.
  - **Mitigation:** Add opt-in Garage-only display mode; default behavior unchanged.
- **Risk:** Heuristic changes could regress other swing types.
  - **Mitigation:** Add fixture-based regression suite before/after heuristic adjustment.

---

## Definition of Done
- Garage import flow is direct, video-only, and auto-importing.
- Garage UI is minimal and analysis-first with immersive video priority.
- Scrubbing defaults to raw frames (no sampled pose overlay noise).
- Manual overrides are complete and durable.
- Early Downswing synchronization issue is corrected and test-covered.
- Status pills render cleanly at compact widths.
```

## File: `docs/IMMEDIATE_IMPLEMENTATION_PLAN.md`

```markdown
# Immediate Implementation Plan (Next 2-4 Weeks)

## Objective
Translate the latest product direction into shippable architecture and module scaffolding while protecting canonical boundaries and local-first behavior.

## Guardrails (Must Hold)
- Canonical module names and boundaries remain unchanged
- No autonomous AI writes
- Offline-first for non-AI flows
- Usefulness and clarity over visual novelty
- The V1 Module Depth Contract in `docs/IMPLEMENTATION_CONTRACT.md` remains authoritative for "first real depth"

## Phase 1: Lock Shared Patterns (Foundation)
### 1.1 Command-center module hub template
Define and document one reusable template used by deep modules:
- top hero status region
- “current state” block
- “next attention” block
- module-local bottom tab scaffold

Deliverables:
- shared hub layout contract (view + view model responsibilities)
- consistent spacing/typography rules for hub sections
- module-tab naming conventions (clear, non-cute labels)

### 1.2 Dashboard card contract v2
Define a single card schema for dashboard module entry:
- progress summary
- urgency/importance indicator (quiet style)
- direct tap target into module hub

Deliverables:
- dashboard card data model contract
- ranking policy: urgency first, importance second
- dashboard three-zone layout contract:
  - top: daily focus + key metric
  - middle: module pulse strip
  - bottom: timeline + quiet alerts

### 1.3 Visual system + composition primitives
Define reusable visual primitives across modules:
- spacing scale tokens
- typography hierarchy tokens
- surface layer rules
- module visualization container contract

Deliverables:
- design-token baseline for spacing/type/surface/color roles
- module composition rule: Hero -> Visualization -> Contextual Actions -> Activity Feed

### 1.4 AI orb + compact panel contract
Define global assistant invocation and panel behavior:
- orb placement rules
- module-context payload passed to assistant
- guided-input flow structure
- approve/reject checkpoint before any write

Deliverables:
- assistant interaction state model
- module-specific rejection reason taxonomy (initial set)

## Phase 2: Scaffold Priority Depth Modules (Structure Only)
This phase is limited to shared command-center scaffolding for depth modules.

In-scope for this phase:
- module hub structure
- internal tab scaffolds
- light routing and placeholder surfaces

Out-of-scope for this phase:
- first full feature depth for these modules
- replacing the V1 Module Depth Contract sequencing

### 2.1 Capital Core (Money)
Implement module hub + internal tabs and thin baseline flows.

Minimum internal tabs:
- Overview
- Entries
- Advisor (optional surface, user-triggered)

### 2.2 Iron Temple (Workouts)
Implement hub + tabs with builder and advisor separation (thin baseline).

Minimum internal tabs:
- Overview
- Builder
- Advisor

### 2.3 Garage
Implement hub + tabs with clear state and action pathways (thin baseline).

Minimum internal tabs:
- Overview
- Records
- Review

## Phase 3: Launch and Dashboard Refinement
### 3.1 Affirmation launch moment
Add a ~4-second affirmation screen with offline fallback content.

Acceptance notes:
- app remains reliable and deterministic
- failures degrade gracefully to local fallback quote/verse

### 3.2 Dashboard rebalance
Adjust dashboard to represent all modules without over-focusing one area.

Acceptance notes:
- progress-first information hierarchy
- direct entry to module hubs
- quiet urgency signaling

## Phase 4: System Consistency Pass
Apply common CRUD/support behaviors across modules where relevant:
- history/archive behavior
- tags strategy
- filter/sort consistency
- confirmation and undo patterns

## Acceptance Checklist
A slice is considered complete when:
- deep modules share the same hub architecture pattern
- dashboard uses the new progress-first entry contracts
- AI orb and compact panel are consistent across enabled modules
- no AI write occurs without explicit confirmation
- canonical module naming remains intact in docs and code

## Risks and Mitigations
- Risk: UI divergence between modules
  - Mitigation: enforce shared hub contract before custom surfaces
- Risk: AI scope creep into autonomous behavior
  - Mitigation: explicit write-approval gate and contract tests
- Risk: dashboard bloat
  - Mitigation: keep dashboard informational + routing only

## Recommended Execution Order
1. Shared hub template + dashboard card contract
2. Visual system + composition primitives
3. AI orb/assistant panel contract
4. Capital Core + Iron Temple + Garage hub/tabs
5. Launch affirmation flow
6. Dashboard rebalance
7. CRUD/history/tags consistency pass
8. Continue first real feature depth in Habit Stack / Task Protocol / Calendar / Supply List per implementation contract

## Simple Step-by-Step (ELI5)
Use this sequence like a checklist:

1. Build one reusable “module home” template.
   - Make the top status area, current state section, and next-action section once.
2. Make one reusable dashboard card.
   - Every module card should show progress and a quiet urgency signal in the same format.
3. Set up one shared visual system.
   - Lock spacing, typography, surfaces, and module visualization containers.
4. Add the AI orb and tiny assistant panel pattern.
   - Keep it input-first and always require approve/reject before writes.
5. Apply the shared template to the three priority depth modules.
   - Capital Core, Iron Temple, and Garage get hubs + internal tabs (scaffolding first).
6. Add the 4-second launch affirmation screen.
   - Include local fallback so it still works offline.
7. Rebalance the dashboard.
   - Ensure all modules are represented and progress appears before urgency lists.
8. Run one consistency pass.
   - Align CRUD/history/tags/filter/sort/undo behavior so modules feel like one system.
9. Do first full depth features in high-frequency modules.
   - Habit Stack, Task Protocol, Calendar, and Supply List stay first for real depth.

If you only do one thing each day, do the next unchecked step in this list.
```

## File: `docs/IMPLEMENTATION_CONTRACT.md`

```markdown
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

## Product Direction Addendum (2026-04)
Use `docs/PRODUCT_DIRECTION_BRIEF.md` for direction on:
- progress-first dashboard composition
- deep module hub-and-tabs command-center pattern
- assistant orb and compact panel behavior

This addendum does not override canonical module names or ownership boundaries.
It also does not override the V1 Module Depth Contract ordering for first full feature depth.

## Sequencing Clarification
Planning docs may schedule early hub/tab scaffolding for Capital Core, Iron Temple, and Garage.

That scaffolding is structural setup only and must not be interpreted as "first real depth."
First real depth remains:
- Habit Stack
- Task Protocol
- Calendar
- Supply List

## Naming Translation Rule
If planning inputs use alternate labels, map to canonical names in code/docs:
- Money => Capital Core
- Workouts => Iron Temple

## Assistant Interaction Contract (Extension)
When AI surfaces are implemented, default interaction must follow:
1. guided input
2. final recommendation
3. explicit approve/reject

By default, assistant responses should be concise and recommendation-forward; detailed reasoning is optional on user request.
```

## File: `docs/MODULE_MAP.md`

```markdown
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
```

## File: `docs/NAVIGATION_AND_SHELL.md`

```markdown
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
```

## File: `docs/PRODUCT_DIRECTION_BRIEF.md`

```markdown
# Product Direction Brief (2026-04)

## Purpose
This brief consolidates the latest product-direction input into implementation-ready guidance that aligns with canonical module names and architecture.

This document **extends** the existing canon; it does not replace:
- `docs/CANONICAL_PRODUCT_SPEC.md`
- `ARCHITECTURE.md`

## Direction Summary
LIFE IN SYNC should behave as a **useful-first personal operating system** for one user:
- private and personal over mass-market appeal
- tool-first over lifestyle branding
- restrained, dependable, and clarity-first
- deeper systems over shallow feature breadth

## Non-Negotiable Decision Rule
When tradeoffs appear:
1. usefulness over beauty
2. usefulness over perceived intelligence

## UX and Visual Direction Additions
These are guiding constraints for implementation detail:
- Keep one coherent system language across the app shell
- Preserve distinct module identity with restrained color accents
- Convey hierarchy using layout, spacing, and typography before color/effects
- Keep confirmation and feedback quiet, fast, and predictable
- Maintain predictable navigation patterns over novelty

Design-system implementation emphasis:
- Define one spacing scale, one typography hierarchy, and explicit color-role mapping
- Use surface layering rules so modules feel distinct but still part of one system
- Keep gradients/glow effects subtle and functional (state/focus), never decorative-first
- Use motion as micro-feedback (transitions/state changes), not as spectacle

## Global Flow Additions
### Launch affirmation
A short (target ~4s) launch affirmation moment is acceptable when:
- it does not block app reliability
- it has offline-safe fallback content
- skip/reduce behavior can be introduced later if needed for speed

Recommended payload:
- app title
- logo mark
- one quote or verse

### Dashboard behavior
The dashboard should prioritize:
- progress visibility before urgency-only lists
- balanced module coverage across the full system
- quick readability with immediate jump paths into modules

Dashboard blueprint preference:
- Hero: daily focus + one key metric
- Middle: module pulse strip (cross-module status at a glance)
- Bottom: timeline + alerts (quiet, actionable, non-alarming)

Priority ranking policy:
- urgency first, then importance
- keep urgency signals subtle, not alarming

## Deep Module Architecture Additions
For deeper modules, prefer a **hub-and-spokes** structure:
- one module home/hub first
- one hero status area at top
- current state first, next actions second
- internal bottom tabs for supporting surfaces

Module screen composition preference:
1. hero summary
2. dynamic visualization block (module-specific)
3. contextual actions
4. activity/feed/history lane

Modules requiring stronger internal command-center structure:
- Garage
- Iron Temple
- Capital Core
- Bible Study
- Calendar

## AI Interaction Additions
AI remains optional and user-controlled, with this default pattern:
1. guided input
2. final recommendation
3. explicit approve/reject

Interaction expectations:
- small, subtle orb-style affordance for invocation
- compact first panel focused on input, not auto-suggestions
- contextual awareness across the current module
- no write/change/save without explicit user confirmation
- concise answer by default; deeper rationale on request

Feedback loop expectations:
- user can reject outputs with quick module-specific reasons
- system may learn preferences over time (without violating explicit-write rule)

## Data Visualization Guidance (Module-Specific)
Prefer meaningful module-native visuals instead of generic stat tiles:
- Habit Stack: streak rings, weekly heatmaps, momentum trend visuals
- Capital Core: trend graphs, clean category grids, cash-flow clarity views
- Iron Temple: performance trend stats, session log summaries, progression visuals
- Bible Study: calm text-first reading/review surfaces with minimal supportive metrics

All visualizations should optimize for decision support, not decoration.

## Tone Additions
Product voice:
- serious
- grounded
- restrained
- quietly premium

Copy rules:
- refined and intentional labels
- neutral empty states
- assistant voice: wise, calm, concise by default

## Canonical Naming Alignment
External wording like “Workouts” and “Money” should map internally to canonical module names:
- Workouts → **Iron Temple**
- Money → **Capital Core**

All implementation artifacts should keep canonical names as source-of-truth identifiers.

## Immediate Documentation and Delivery Implications
Before heavy UI polish, lock reusable architecture patterns for deep modules and AI surface behavior.

Use `docs/IMMEDIATE_IMPLEMENTATION_PLAN.md` as the execution sequence for next steps.
```

## File: `docs/REPO_SYNC_WORKFLOW.md`

```markdown
# Repo Sync Workflow

## Canonical topology

There is exactly one real repository checkout for this project:

- `/Users/colton/Desktop/LIFE-IN-SYNC`

## Source of truth

GitHub is the cross-device sync engine.

- Mac changes sync by `git push`
- iPhone changes sync by pulling and pushing through a Git-capable app
- Local folders do not auto-merge branch state for you

## iPhone workflow

Use Working Copy on iPhone with the GitHub repository.

Recommended loop:

1. Pull in Working Copy before editing
2. Make the change on iPhone
3. Commit in Working Copy
4. Push to GitHub
5. Pull on Mac before continuing

Do not depend on iCloud Drive Files as a live repo editor for this project.

## Mac workflow

Always work from:

- `/Users/colton/Desktop/LIFE-IN-SYNC`

Before starting:

1. Confirm the branch with `git branch --show-current`
2. Confirm status with `git status --short --branch`
3. Pull the branch you plan to use

Before switching devices:

1. Commit intentional changes
2. Push the branch
3. If the work should appear on GitHub `main`, merge the feature branch first

## Branch expectations

If local code and GitHub look different, check these in order:

1. Are you on `main` locally?
2. Is GitHub showing `main` while local is on a feature branch?
3. Has the feature branch been pushed?
4. Has it been merged back into `main`?

Most "not in sync" cases for this repo are branch mismatches, not duplicate code copies.
```

## File: `docs/ROADMAP.md`

```markdown
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
```

## File: `docs/TASK_RETROSPECTIVE_2026-04-02.md`

```markdown
# Task Retrospective (2026-04-02)

## Scope Reviewed
Previous task: convert the supplied product-direction answer into practical project documentation and add an immediate implementation plan.

## Self-Rating
**8.0 / 10**

## What Went Well
- Captured core direction (useful-first, command-center module depth, subdued UI tone) into implementation-facing docs.
- Added a focused immediate execution plan with phased delivery, acceptance criteria, and risk controls.
- Preserved canonical naming and module boundaries while mapping alternate language (Money/Workouts) to canonical module names.
- Linked new planning artifacts into the roadmap for discoverability.

## What Could Have Been Better
- Did not include a plain-language “how to execute this plan” section for non-technical review.
- Did not provide a direct self-assessment and confidence statement in the follow-up response.
- Could have added a tighter weekly cadence/checklist view to make day-to-day execution easier.

## Most Immediate Improvements Applied
1. Added an ELI5-style step-by-step section directly inside `docs/IMMEDIATE_IMPLEMENTATION_PLAN.md`.
2. Clarified that teams can execute the plan by simply completing the next unchecked step in sequence.

## Quality Bar Going Forward
For strategy-to-implementation documentation updates, always include:
- Strategic synthesis
- Implementation contract impact
- Time-boxed execution plan
- ELI5 operational checklist
- Acceptance criteria and risk controls
- One-paragraph self-review in the delivery note
```

## File: `docs/TEST_EXECUTION_BLOCKER.md`

```markdown
# Test Execution Blocker

## Status
As of April 2, 2026, the project builds successfully in Xcode, but test execution is cancelled before any test body runs.

Observed result:
- `RunAllTests` returns 9 tests with `No result`
- app build succeeds
- unit tests and UI tests do not begin execution

## Current Symptom
The Xcode test runner reports:

`Testing cancelled because the build failed.`

Then immediately reports a coverage-toolchain failure during:

`Generating coverage report`

The blocking message is:

`libLTO.dylib is not present in the toolchain at path ... Metal.xctoolchain`

## What Has Already Been Tried
- disabled launch affirmation during UI tests using `SKIP_LAUNCH_AFFIRMATION`
- set `codeCoverageEnabled = "NO"` in the shared scheme
- replaced the auto-created test plan with a committed shared test plan: [LIFE-IN-SYNC.xctestplan](/Users/colton/Desktop/LIFE-IN-SYNC/LIFE-IN-SYNC.xctestplan)
- confirmed the app still builds after those changes

These steps did not stop Xcode from entering a coverage-report phase before test execution.

## Likely Cause
The remaining blocker appears to be environment-level rather than repo-level.

Most likely sources:
- Xcode or derived-data state still forcing coverage collection
- simulator/toolchain state on this Mac
- an Apple toolchain installation issue related to the referenced Metal toolchain

## Current Workaround
- treat `BuildProject` as the reliable verification step for code integration
- keep UI tests deterministic with the launch skip argument already in place
- do not interpret the current test failure as an app-logic regression until the local Xcode toolchain issue is cleared

## Next Environment Checks
Perform these in Xcode/macOS before expecting green test runs:
- verify `Gather coverage` is off in the active scheme's Test action
- clean derived data for this project
- restart Xcode
- verify simulator services are healthy
- confirm the active Xcode installation is complete and selected correctly
- if the issue persists, reinstall or repair the affected Xcode toolchain/runtime components
```

## File: `docs/VISION.md`

```markdown
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
```

## File: `docs/google_gemini_custom_gem_source_text.md`

```markdown
# Google Gemini Custom Gem — Source Text

Use the following source text as the **full instruction block** for a Gemini custom Gem.

---

You are a senior iOS engineer working in a Swift / SwiftUI codebase.

Your default operating focus:
- SwiftUI architecture
- maintainable state management
- safe refactoring
- clean UI implementation
- deterministic testing
- production-ready code (not demos or shortcuts)

## Core Rules

### 1) Understand before editing
- Inspect relevant files and nearby code paths before making changes.
- Identify and follow the existing architectural pattern unless explicitly asked to change it.
- Do not introduce unnecessary new abstractions (managers/coordinators/services/wrappers).

### 2) Preserve architecture
- Extend current systems instead of building parallel systems.
- Avoid broad rewrites unless required.
- Keep blast radius small and scoped to the requested outcome.

### 3) Swift / SwiftUI standards
- Use idiomatic Swift and modern SwiftUI patterns.
- Keep views small and composable.
- Move non-view logic out of views when appropriate.
- Avoid combining UI + business logic + transformation code in one large view file.
- Prefer clear, predictable naming and structure over cleverness.

### 4) UI implementation quality
- Build polished, restrained, production-quality UI.
- Respect spacing, hierarchy, readability, and touch targets.
- Avoid clutter, gimmicks, and unnecessary visual effects.
- Prefer clarity and stability over novelty.
- Consider loading, empty, error, partial, and overflow states.

### 5) State management
- Keep state ownership explicit and local when possible.
- Avoid duplicated state unless necessary.
- Avoid storing the same derived state in multiple places.
- Prevent fragile chains of bindings and side effects.
- Be careful with async transitions, lifecycle triggers, and race conditions.

### 6) Safe changes only
- Do not remove existing behavior unless obsolete or explicitly required.
- Call out possible breakage risks.
- Prefer incremental edits over broad rewrites.
- Preserve public interfaces unless task requirements demand changes.

### 7) Debugging approach
- Do not guess. Trace issues to the root cause.
- Distinguish root cause vs. symptom.
- If tests fail, do not weaken tests unless they are incorrect.
- Prefer fixing implementation over patching around defects.

### 8) Testing expectations
- Run the most relevant narrow test suite first.
- Report exactly what was run, what passed, what failed, and what remains unverified.
- Never claim a fix without validation.
- If tests cannot run, state why clearly.

### 9) Response format (always)
For every meaningful task, provide:
1. What you changed
2. Why you changed it
3. Files touched
4. Risks / follow-ups
5. Exact validation performed

### 10) When requirements are vague
- Infer the most production-sensible approach from existing code.
- Do not ask unnecessary questions if code context already indicates direction.
- If multiple approaches are valid, choose the lowest-complexity, highest-maintainability option.

### 11) Performance and reliability
- Avoid unnecessary re-renders and expensive work in `body`.
- Be careful with broad invalidation from large observable objects.
- Prefer deterministic, testable logic.
- Treat animation, gestures, and async interactions carefully.

### 12) No fake completion
- Do not claim “done” if work is partial.
- Clearly separate completed work from suggested next steps.
- Surface uncertainty directly.

## Preferred Engineering Qualities
- explicit over magical
- modular over monolithic
- readable over clever
- stable over flashy
- validated over assumed

## Output Standards
- Use concise, structured Markdown.
- Include implementation details that are actionable and reviewable.
- Keep recommendations aligned with the current architecture.
- Optimize for long-term maintainability in a real production app.

---

(Optional) If Gemini supports “Tone” settings, choose:
- Professional
- Direct
- High-signal
- Low-fluff

```

## File: `scripts/ci/capture_screenshots.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="artifacts/screenshots"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
APP_BUNDLE_PATH="${APP_BUNDLE_PATH:-}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-}"

mkdir -p "$OUT_DIR"

cleanup() {
  echo "Shutting down simulator: $SIMULATOR_NAME"
  xcrun simctl shutdown "$SIMULATOR_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Booting simulator: $SIMULATOR_NAME"
boot_stderr="$(mktemp)"
if ! xcrun simctl boot "$SIMULATOR_NAME" 2>"$boot_stderr"; then
  if xcrun simctl list devices "$SIMULATOR_NAME" | grep -q "(Booted)"; then
    echo "simctl boot returned a non-zero exit code, but the simulator is already booted; continuing."
  else
    echo "Failed to boot simulator: $SIMULATOR_NAME" >&2
    cat "$boot_stderr" >&2
    rm -f "$boot_stderr"
    exit 1
  fi
fi
rm -f "$boot_stderr"
xcrun simctl bootstatus "$SIMULATOR_NAME" -b

fallback_path="$OUT_DIR/launch.png"

if [[ -n "$APP_BUNDLE_PATH" && -d "$APP_BUNDLE_PATH" && -n "$APP_BUNDLE_ID" ]]; then
  echo "Installing app for screenshot capture: $APP_BUNDLE_ID"
  echo "Removing any existing simulator install for: $APP_BUNDLE_ID"
  xcrun simctl uninstall booted "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

  echo "Installing app bundle from: $APP_BUNDLE_PATH"
  if [[ -f "$APP_BUNDLE_PATH/Info.plist" ]]; then
    echo "Found app bundle Info.plist at: $APP_BUNDLE_PATH/Info.plist"
  fi

  install_stderr="$(mktemp)"
  if ! xcrun simctl install booted "$APP_BUNDLE_PATH" 2>"$install_stderr"; then
    echo "simctl install failed for app bundle: $APP_BUNDLE_PATH" >&2
    cat "$install_stderr" >&2
    rm -f "$install_stderr"
    exit 1
  fi
  rm -f "$install_stderr"

  echo "Launching app for screenshot capture: $APP_BUNDLE_ID"
  xcrun simctl terminate booted "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch booted "$APP_BUNDLE_ID"
  sleep 3
else
  echo "Missing APP_BUNDLE_PATH or APP_BUNDLE_ID for screenshot capture." >&2
  exit 1
fi

xcrun simctl io booted screenshot "$fallback_path"

echo "Exported screenshot artifacts to:"
echo "$fallback_path"
```

## File: `scripts/repo-health.sh`

```bash
#!/bin/zsh

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
current_branch="$(git branch --show-current)"

echo "Repo root: $repo_root"
echo "Branch: $current_branch"
echo
echo "Status:"
git status --short --branch
echo
echo "Remote:"
git remote -v | head -n 2
echo
echo "Access points:"
for path in \
  "/Users/colton/Desktop/LIFE-IN-SYNC" \
  "/Users/colton/Library/Mobile Documents/com~apple~CloudDocs/LIFE-IN-SYNC"
do
  if [[ -L "$path" ]]; then
    echo "$path -> $(/usr/bin/stat -f '%Y' "$path")"
  elif [[ -e "$path" ]]; then
    echo "$path"
  else
    echo "$path (missing)"
  fi
done
```

