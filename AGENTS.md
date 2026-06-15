## Strict Verification Budget

- Never run simulators, Computer Use, screenshots, or visual QA unless explicitly requested.
- Never run more than one full Xcode build per task.
- For normal SwiftUI edits, run only:
  - `xcrun swiftc -parse` on changed files
  - `git diff --check`
- Do not run whole-app type checks unless focused parsing fails.
- Stop any verification command after 60 seconds.
- Do not retry a stalled command.
- Report unverified runtime behavior honestly.

## Repo Workflows and Commands

- Use `./scripts/repo-health.sh` for a quick repo root, branch, status, and remote check.
- Before Garage Tempo Builder edits, prove the live route with:
  - `rg -n "tempoBuilder|GarageTempoBuilderView|GarageTempoWizard" LIFE-IN-SYNC/Garage --glob '*.swift'`
  - The current route is `GarageView.swift -> .tempoBuilder -> GarageTempoBuilderView()` in `HorizonVaultDialView.swift`; treat `GarageTempoWizard.swift` as legacy unless routing changes.
- Run focused Swift parsing from the repo root with `xcrun swiftc -parse <changed-file.swift>`.
- This macOS environment does not provide `timeout`. When a hard 60-second cap is needed, use `/usr/bin/perl -e 'alarm shift; exec @ARGV' 60 <command>`.
