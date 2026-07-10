# Implementation Plan: Direct Mode — Hotspot File Transfer

**Branch**: `001-direct-transfer` | **Date**: 2026-07-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-direct-transfer/spec.md`

## Summary

Direct Mode turns LocalSend-Enhanced into a Xender/SHAREit-class **offline**
transfer tool: a host Android device raises a local-only WiFi hotspot (no
internet), shows a QR, and guests (phones via app, computers via browser) join
that direct link and transfer with no router and no data.

The key realization from a codebase audit: **most of the transfer surface
already exists upstream** and only needs assembling + a working connection
layer. What exists today:

- **Isolate HTTP server + transfer protocol** (`server_provider`,
  `receive_controller`, `send_controller`) — the actual file movement.
- **Web send to a browser** — `WebSendPage` + `send_controller.installRoutes`
  serve a full browser UI (`Assets.web.index` / `main.js`) with PIN + optional
  encryption. This covers "PC downloads from phone" (part of P2).
- **APK / installed-app picker** (`apk_picker_page.dart`) — part of P4.
- **Directory picking** (`pick_directory_path.dart`, `open_folder.dart`) — part
  of P4 folder send.
- **QR generation** (`qr_dialog.dart`) and **history** (`receive_history_provider`,
  persisted) — part of P1 pairing and P5 history.
- **WiFi Direct scaffolding** (`WifiDirectService`, `WifiDirectPlugin.kt` with
  `startLocalOnlyHotspot`, `HotspotCredentials.toQrPayload`) — the incomplete
  connection layer.

Therefore the plan concentrates real work on: (1) completing the **connection
layer** (host returns its AP IP; guest auto-joins and *binds* its traffic to the
hotspot; direct registration instead of multicast), (2) a dedicated **Direct
tab/flow** that orchestrates host/guest, (3) **browser upload** (PC→phone) to
finish P2, (4) **group-send fan-out**, and (5) **resume**. Everything else is
integration of existing parts.

## Technical Context

**Language/Version**: Dart 3.x + Flutter 3.38.10 (app, CI-locked); Dart (common package); Kotlin (Android native `WifiDirectPlugin`).

**Primary Dependencies**: refena (state), isolate-based `SimpleServer` HTTP stack, rhttp, `qr_flutter`/QR dialog, `mobile_scanner` (QR scan — verify present, else add), existing bundled web assets (`Assets.web.*`), `dart_mappable` for models.

**Storage**: SharedPreferences via `PersistenceService` (history, session prefs); files on disk via existing save/receive pipeline.

**Testing**: `flutter test` (app), `dart test` (common); analyzer gate `--no-fatal-infos`. CI at Flutter 3.38.10 (local builds blocked by NTFS/Rust — CI is the gate).

**Target Platform**: Host = Android (local-only hotspot). Guests = Android/desktop (app) and any browser (no app). Desktop hosting is out of scope for v1.

**Project Type**: Cross-platform Flutter mobile+desktop app with an embedded HTTP/web server.

**Performance Goals**: Transfer saturates the local WiFi link (bounded by radio, not internet); pairing→first byte within a few seconds of QR scan.

**Constraints**: Fully offline (no internet on the hotspot); must restore the guest's prior network after a session; resilient to guest drop-off during group send.

**Scale/Scope**: In-person sessions; up to ~8 simultaneous guests; individual files up to multi-GB (videos/apps).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution (`.specify/memory/constitution.md`) is currently the
**unpopulated template** — no ratified principles to gate against. Applying the
global engineering principles in force for this codebase instead:

- **Reuse over rebuild (DRY/YAGNI)**: PASS — the plan explicitly reuses the
  existing server, web-send, APK picker, directory picker, QR, and history
  rather than duplicating them.
- **Separation of concerns**: PASS — connection layer (native + service),
  session orchestration (providers), and presentation (Direct tab) are distinct.
- **Fail fast / clear errors**: PASS — spec FR-024/FR-026 require explicit
  capability/permission/failure messaging.
- **Testability**: PASS — each user story is independently testable (see
  quickstart.md); connection layer is mockable behind `WifiDirectService`.
- **Versioning discipline**: PASS — feature branch `001-direct-transfer`,
  ships via the existing release CI as `enhanced-v1.1.0`.

No violations requiring Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/001-direct-transfer/
├── plan.md              # This file
├── research.md          # Phase 0 — technical decisions
├── data-model.md        # Phase 1 — entities & state
├── quickstart.md        # Phase 1 — end-to-end validation scenarios
├── contracts/           # Phase 1 — QR payload, pairing, web-upload, group-send
│   ├── qr-pairing.md
│   ├── web-transfer.md
│   └── group-send.md
├── checklists/
│   └── requirements.md  # Spec quality checklist (done)
└── tasks.md             # Phase 2 — created by /speckit-tasks
```

### Source Code (repository root)

New and modified paths within the existing LocalSend layout:

```text
app/
├── android/app/src/main/kotlin/org/localsend/localsend_app/
│   └── WifiDirectPlugin.kt            # MODIFY: return AP IP on startHotspot;
│                                      #         bindProcessToNetwork on join;
│                                      #         expose connected-client info
├── lib/
│   ├── pages/direct/                  # NEW: dedicated Direct tab/flow
│   │   ├── direct_tab.dart            #   host/guest entry (Start / Scan)
│   │   ├── direct_host_page.dart      #   hotspot QR + connected devices + send
│   │   ├── direct_join_page.dart      #   scan QR / manual code → auto-connect
│   │   └── direct_group_send_page.dart#   pick targets (incl. "all") + progress
│   ├── provider/direct/               # NEW: session orchestration
│   │   ├── direct_session_provider.dart   # host/guest session state machine
│   │   └── direct_pairing.dart            # QR payload encode/decode (extends
│   │                                      # HotspotCredentials)
│   ├── service/
│   │   ├── wifi_direct_service.dart         # MODIFY: startHotspot→credentials+IP;
│   │   │                                    #         joinHotspot→bound network
│   │   └── platform/android_wifi_direct_service.dart  # MODIFY: new channel calls
│   ├── provider/network/server/controller/
│   │   ├── send_controller.dart       # MODIFY: add browser UPLOAD route (PC→phone)
│   │   └── receive_controller.dart    # (resume support hook — offset/range)
│   └── provider/network/
│       └── direct_group_send.dart     # NEW: fan-out one selection to N targets
└── assets/web/                        # MODIFY/ADD: browser upload UI asset
```

**Structure Decision**: Extend the existing single Flutter app. Direct Mode is a
new **feature area** (`pages/direct/`, `provider/direct/`) that orchestrates
already-present services (HTTP server, web-send, pickers, history) plus the
completed native connection layer. No new project or package is introduced.

## Phased Delivery (maps to spec user stories)

The stories are independently shippable; implementation follows their priority so
each phase is a demoable slice.

- **Phase A (P1) — Direct phone↔phone**: complete `WifiDirectPlugin` (AP IP +
  guest bind), extended QR payload, `direct_session_provider`, `direct_tab` +
  host/join pages, direct registration to known host IP (bypass multicast).
  *Demo*: two airplane-mode phones transfer a file.
- **Phase B (P2) — No-app PC web transfer**: reuse `WebSendPage` server for
  download; add a browser **upload** route + asset for PC→phone; surface the URL
  on the host screen. *Demo*: laptop browser sends & receives, no install.
- **Phase C (P3) — Group send**: `direct_group_send` fan-out, per-device progress
  UI, isolate failure isolation. *Demo*: one host → 4 guests at once.
- **Phase D (P4) — Send anything**: wire folder picker (structure preserved),
  album selection, and the existing APK picker into the Direct send flow.
- **Phase E (P5) — Resume + history**: offset/range resume on the upload path;
  ensure Direct transfers land in the persisted history with re-open/re-share.

## Complexity Tracking

No constitution violations; no entries required.
