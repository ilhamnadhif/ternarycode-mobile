# TernaryCode Mobile (Android · Flutter)

Native Android remote companion app for **TernaryCode** desktop — built with Flutter + Impeller using the exact **Slate** design language (`design/index.html`).

## Features

- **QR & Manual Pairing + Wi-Fi LAN Discovery**: Scan the QR code from desktop `Settings → Phone` (`http://<lan-ip>:7890/?pair=<code`> or Tailscale / Cloudflare / ngrok tunnel) or enter address & code manually with automatic Wi-Fi subnet discovery.
- **Android Keystore Token Security**: Each paired host stores its revocable Bearer token inside Android Keystore (`flutter_secure_storage`) with multi-host switching and clean offline/revoked recovery.
- **Live Terminal & Agent Control**: Real-time Server-Sent Events (`/api/events`), ANSI SGR + diff-tinted output rendering, amber attention rings, thumb-sized `Approve / Reject / Stop` controls, quick terminal keys (`Enter`, `Esc`, `^C Stop`, `Tab`, `↑`, `↓`), prompt composer, and Fullscreen Terminal (`A− / A+` zoom, line wrap toggle, scrollback pill, copy).
- **1-Tap Rate Limit Failover**: Same-provider prioritized `Resume <profile>` buttons when an agent hits its 5h/weekly limit, plus compact `Switch account` chips while running.
- **Inbox, Projects & Quotas**: Cross-project oldest-first Inbox (`All / Needs you / Finished`) with inline actions and full command inspection; searchable Projects & Worktrees with 1-tap `Resume`; Accounts & Quotas with ranked 5h + weekly meters and reset countdowns.
- **In-App APK Self-Updater**: Checks `ilhamnadhif/ternarycode-mobile` GitHub Releases on launch & from `Settings → Check`, selects the phone's exact ABI (`arm64-v8a` / `armeabi-v7a` / `x86_64`), streams download with progress bar, verifies `SHA256SUMS.txt`, and launches Android's native PackageInstaller via `FileProvider`.
- **Android OS Integration**: Actionable Android notifications (`Approve`, `Reject`, `Resume`) on the lock screen, optional biometric confirmation before approving, haptic feedback, and Slate Dark & Light themes.
- **Interactive Demo Mode**: Preview every screen immediately without a desktop host from the Welcome screen.

## Quick Build & Sideload Install

```bash
flutter pub get
flutter analyze
flutter test

# Build arm64 APK for modern Android phones (~30 MB)
flutter build apk --release --split-per-abi

# Install directly over USB (ADB)
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Design Specification

Open [`design/index.html`](design/index.html) directly in any browser to view all 14 screens, the interactive prototype, Slate Dark/Light tokens, and the Companion API mapping.
