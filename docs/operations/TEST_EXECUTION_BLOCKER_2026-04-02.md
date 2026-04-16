# Test Execution Blocker

## Status: active incident/blocker note (as of 2026-04-02).


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
