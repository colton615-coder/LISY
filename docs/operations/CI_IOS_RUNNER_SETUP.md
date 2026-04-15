# iOS CI Runner Setup (Self-Hosted macOS)

## Status: operational runbook.


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
