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
