# TernaryCode Mobile — Design Spec (Flutter / Android)

Interactive HTML specification and clickable prototype for the TernaryCode Android remote client, built directly on TernaryCode's **Slate** design system (`design/figcraft/tokens.py` & `src/ui/style.rs`).

## Open the Design

Open `design/index.html` directly in any browser (works offline via `file://`, zero build step):
- **All Screens (14)** — complete 4-flow board at Android `390 × 844` logical viewport.
- **Interactive Prototype** — live clickable Android phone (approve/reject agents, watch terminal output update, test 1-tap rate-limit failover, send prompts, switch hosts, toggle Dark/Light theme, and preview Android lock-screen quick-approve notifications).
- **Tokens & API** — exact Slate Dark/Light colour palette, Companion API endpoints, and Flutter Android architecture summary.

## Screen Inventory (14 Screens)

| Flow | # | Screen | Purpose |
| :--- | :-: | :--- | :--- |
| **01 Pairing & Hosts** | 01 | Welcome & Pair | Native QR scan primary CTA, manual fallback, Keystore security note |
| | 02 | QR Camera Scanner | Live camera viewfinder with detected host/code 1-tap pair pill & torch |
| | 03 | Manual Pairing & mDNS | LAN/Cloudflare/Tailscale URL, code, device name, mDNS shortcut, preserved draft on error |
| | 04 | Host Switcher & Offline | Multi-computer bottom sheet (Mac/Linux/Windows) + clean reconnect/retry state |
| **02 Live Terminal** | 05 | Live · Needs Input | Amber attention ring, diff output, Notice card, Approve/Reject/Stop, quick terminal keys |
| | 06 | Live · Rate Limit Failover | Orange limit Notice + same-provider prioritized `Resume on claude2` / cross-provider handoff |
| | 07 | Live · Running & Switcher | Streaming Codex output, compact account swap chips, Esc/^C/Tab/arrows accessory strip |
| | 08 | Fullscreen Terminal | Distraction-free output reader with A−/A+ zoom, wrap toggle, scrollback jump pill |
| **03 Inbox & Projects** | 09 | Inbox · Attention Queue | All / Needs you / Finished segmented filter with inline Approve/Reject/Resume actions |
| | 10 | Inbox · Item Detail | Command box, hook provenance, Approve/Reject/Open Live + embedded live terminal tail |
| | 11 | Projects & Worktrees | Filterable project cards with Slate letter avatars, branches, worktrees, Live tags & Resume |
| **04 Accounts & OS** | 12 | Accounts & Quotas | Summary strip, failover policy, ranked accounts with 5h + weekly meters & reset countdowns |
| | 13 | Settings & APK Updates | Android Foreground Service keep-alive, per-event notifications, biometric lock, APK updater |
| | 14 | Android Lock Screen | Native notification shade with inline `Approve`, `Reject`, and `Resume on claude2` actions |

## Desktop Companion API Alignment

Compatible with TernaryCode desktop `v0.3.12+` (`src/companion.rs`):
- `POST /api/pair` — exchange pairing token for per-device Bearer token (stored in Android Keystore via `flutter_secure_storage`).
- `GET /api/state` — initial `CompanionSnapshot` (`host_os`, `failover_mode`, `projects`, `panes`, `profiles`, `alerts`).
- `GET /api/events?token=...` — live SSE updates (with 15s keepalive & immediate revoke termination).
- `POST /api/pane/:id/input` — `{ action: "approve" | "reject" | "interrupt" }` or `{ text, enter }`.
- `POST /api/pane/:id/switch-profile` — `{ profile_id }` for 1-tap account failover/switching.
- `POST /api/session/resume` — `{ project_id, agent, session_id, profile_id }`.
