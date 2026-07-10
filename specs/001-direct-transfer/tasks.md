---

description: "Task list for Direct Mode — Hotspot File Transfer"
---

# Tasks: Direct Mode — Hotspot File Transfer

**Input**: Design documents from `specs/001-direct-transfer/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included only for pure-logic units that are testable without hardware
(pairing codec, group fan-out, resume math). Hotspot/native paths are validated
via `quickstart.md` on real devices, not automated tests.

**Organization**: Grouped by user story (P1–P5) for independent implementation
and demoable increments. Reuses existing LocalSend surface wherever possible
(server, web-send, APK picker, directory picker, QR, history).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete work)
- **[Story]**: US1–US5 maps to spec user stories

## Path Conventions

Existing LocalSend Flutter app: app code under `app/lib/`, Android native under
`app/android/app/src/main/kotlin/org/localsend/localsend_app/`, web assets under
`app/assets/web/`, tests under `app/test/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Dependencies and feature scaffolding

- [ ] T001 [P] Add `mobile_scanner` to dependencies in `app/pubspec.yaml` (guest QR scanning; generation stays on `pretty_qr_code`)
- [ ] T002 [P] Create feature directories `app/lib/pages/direct/`, `app/lib/provider/direct/`, `app/lib/model/state/direct/`, `app/test/direct/`
- [ ] T003 Register a "Direct" section entry point in navigation in `app/lib/pages/home_page.dart` and `app/lib/pages/home_page_controller.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The hotspot connection substrate + core models every story builds on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 [P] Extend `startHotspot` in `app/android/app/src/main/kotlin/org/localsend/localsend_app/WifiDirectPlugin.kt` to resolve and return the AP host IPv4 (enumerate `NetworkInterface` on the softAP/tether interface) in the channel result (research §1)
- [ ] T005 Extend join/leave in `app/android/app/src/main/kotlin/org/localsend/localsend_app/WifiDirectPlugin.kt`: hold the `WifiNetworkSpecifier` `Network`, call `bindProcessToNetwork(network)` on join and `bindProcessToNetwork(null)` on leave (research §2/§3)
- [ ] T006 Update `HotspotCredentials` + `WifiDirectService` to carry `hostIp`/`port`/`protocol`; `startHotspot` returns credentials+IP; `joinHotspot` binds the network in `app/lib/service/wifi_direct_service.dart`
- [ ] T007 Update `AndroidWifiDirectService` channel calls for the new `startHotspot` result and bind/unbind in `app/lib/service/platform/android_wifi_direct_service.dart`
- [ ] T008 [P] Implement `PairingPayload` encode/decode (`lsd://v1/<base64url(json)>` primary + `WIFI:` fallback) extending `toQrPayload`/`fromQrPayload` in `app/lib/provider/direct/direct_pairing.dart` (contract: contracts/qr-pairing.md)
- [ ] T009 [P] Create core Direct models `DirectSession`, `GuestConnection`, `Participant`, `TransferItem` with `dart_mappable` in `app/lib/model/state/direct/` (data-model.md)
- [ ] T010 Create `direct_session_provider.dart` (host/guest session state machine + participant list, per data-model state machines) in `app/lib/provider/direct/`
- [ ] T011 Create the Direct tab scaffold `direct_tab.dart` with prominent **Send** (host) / **Receive** (join) actions in `app/lib/pages/direct/`
- [ ] T012 [P] Unit test `PairingPayload` round-trip (encode→decode, both `lsd://` and `WIFI:`) in `app/test/direct/direct_pairing_test.dart`

**Checkpoint**: Connection substrate + models + Direct tab shell ready

---

## Phase 3: User Story 1 - Phone↔phone direct transfer via QR (Priority: P1) 🎯 MVP

**Goal**: Two phones transfer a file fully offline: host makes hotspot+QR, guest scans → auto-joins → connects → receives.

**Independent Test**: Both phones in airplane mode + WiFi on; host starts, guest scans, a chosen file transfers end-to-end (quickstart Scenario 1).

- [ ] T013 [US1] Implement `direct_host_page.dart` (start hotspot, render QR from `PairingPayload` via `pretty_qr_code`, show connected devices, end-session button) in `app/lib/pages/direct/direct_host_page.dart`
- [ ] T014 [US1] Implement `direct_join_page.dart` (`mobile_scanner` camera → decode payload → join hotspot → bind → register) in `app/lib/pages/direct/direct_join_page.dart`
- [ ] T015 [US1] Implement direct registration path in `app/lib/provider/direct/direct_session_provider.dart` — guest announces to `host:port` with `sessionToken`; host admits and adds a `Participant` (reuse `scan_facade`/register, research §5)
- [ ] T016 [US1] Wire single-file send over the direct link to a `Participant` using the existing send session in `app/lib/pages/direct/direct_host_page.dart`
- [ ] T017 [US1] Implement teardown + network restoration (stop hotspot, unbind) on end/leave in `app/lib/service/wifi_direct_service.dart` and `direct_session_provider.dart` (FR-006)
- [ ] T018 [US1] Manual-join fallback UI (SSID/password + short code) for API<29 / camera denied in `app/lib/pages/direct/direct_join_page.dart` (FR-024)
- [ ] T019 [US1] Status + error surfaces (creating hotspot, waiting, connected, progress, errors) across `direct_host_page.dart` / `direct_join_page.dart` (FR-023)

**Checkpoint**: MVP — offline phone→phone transfer works and is demoable

---

## Phase 4: User Story 2 - No-app PC / laptop web transfer (Priority: P2)

**Goal**: A computer with no app joins the hotspot, opens a browser URL, and sends/receives both directions.

**Independent Test**: Laptop browser uploads a file to the phone and downloads one from it, no install (quickstart Scenario 2).

- [ ] T020 [US2] Add browser upload handling in `app/lib/provider/network/server/controller/send_controller.dart` — accept web-client uploads via the existing `ApiRoute.upload.*` handshake, auto-accepted within a Direct session (contracts/web-transfer.md)
- [ ] T021 [P] [US2] Add a browser **upload** view (HTML/JS POSTing to the upload route) to the served web assets in `app/assets/web/` (extend index/main.js)
- [ ] T022 [US2] Surface the host web URL alongside the QR in `app/lib/pages/direct/direct_host_page.dart` (FR-007)
- [ ] T023 [US2] Ensure browser-originated transfers are recorded in history (FR-009) via the receive/history path
- [ ] T024 [US2] Represent browser clients as `Participant`s (`platform=browser`) in the host device list in `app/lib/provider/direct/direct_session_provider.dart`

**Checkpoint**: PC browser transfer both directions, no install; works alongside app guests

---

## Phase 5: User Story 3 - Group send, one host to many (Priority: P3)

**Goal**: Host sends one selection to multiple connected guests at once with per-device progress and failure isolation.

**Independent Test**: 3+ guests join; host sends to "all"; each receives; killing one guest's WiFi doesn't stop the others (quickstart Scenario 3).

- [ ] T025 [P] [US3] Implement `direct_group_send` coordinator (fan-out one selection to N `Participant`s, concurrent, failure-isolated) in `app/lib/provider/network/direct_group_send.dart` (contracts/group-send.md, research §8)
- [ ] T026 [US3] Implement target-selection UI (list `Participant`s + "send to all") in `app/lib/pages/direct/direct_group_send_page.dart`
- [ ] T027 [US3] Per-device progress + final outcome display in `app/lib/pages/direct/direct_group_send_page.dart` (FR-017)
- [ ] T028 [US3] Guarantee one device failing/disconnecting doesn't abort the others in `app/lib/provider/network/direct_group_send.dart` (FR-018)
- [ ] T029 [P] [US3] Unit test fan-out failure-isolation logic in `app/test/direct/direct_group_send_test.dart`

**Checkpoint**: One host → many guests, robust to drop-offs

---

## Phase 6: User Story 4 - Send folders, albums, and installed apps (Priority: P4)

**Goal**: Direct send supports folders (structure preserved), whole albums, and installed apps as installable packages.

**Independent Test**: Send a nested folder, an album, and an installed app; each arrives complete (quickstart Scenario 4).

- [ ] T030 [P] [US4] Wire folder source into Direct send (reuse `pick_directory_path`; preserve `relativePath`) in `app/lib/pages/direct/direct_host_page.dart` and selection provider (FR-011)
- [ ] T031 [P] [US4] Wire album (photo/video) multi-select source into Direct send via the existing media selection (FR-012)
- [ ] T032 [P] [US4] Wire installed-app source via `app/lib/pages/apk_picker_page.dart` into the Direct send flow (FR-013)
- [ ] T033 [US4] Receiver: preserve folder structure on save and offer install for received `.apk` (existing open/install intent) in the receive path (FR-011/FR-013)
- [ ] T034 [US4] Overall + per-item progress for multi-item selections in the Direct send UI (FR of P4)

**Checkpoint**: "Send anything" works

---

## Phase 7: User Story 5 - Resume interrupted transfers + history (Priority: P5)

**Goal**: Interrupted transfers resume from the last point; a persistent history records sent+received with re-open/re-share.

**Independent Test**: Interrupt a large transfer and confirm it resumes (not restarts); confirm history persists across restart (quickstart Scenario 5).

- [ ] T035 [US5] Extend the prepare-upload response to report `receivedBytes` per (session,file) in the common DTO and `app/lib/provider/network/server/controller/receive_controller.dart` (research §9)
- [ ] T036 [US5] Sender: seek to the reported offset and stream the remainder on resume in the send path
- [ ] T037 [US5] Mark interrupted transfers resumable and auto-resume on reconnect within the session in `app/lib/provider/direct/direct_session_provider.dart` (FR-019)
- [ ] T038 [P] [US5] Persist Direct transfers (sent+received, `via=direct`) to history with re-open/re-share in `app/lib/provider/receive_history_provider.dart` / persistence (FR-020/FR-021)
- [ ] T039 [P] [US5] Unit test resume offset math (`receivedBytes` → resume stream) in `app/test/direct/resume_test.dart`

**Checkpoint**: Resume + persistent Direct history

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Robustness, i18n, and release

- [ ] T040 [P] Capability/permission messaging (no hotspot support, denied nearby/location/storage, no camera) with fallbacks across `app/lib/pages/direct/`
- [ ] T041 [P] Add i18n strings for Direct Mode (slang) under `app/lib/i18n/` and regenerate translations
- [ ] T042 Verify network restoration after session end on both roles (internet returns) — quickstart regression
- [ ] T043 Verify standard same-network LocalSend transfer still works (no regression)
- [ ] T044 Run `flutter analyze --no-fatal-infos` + `dart format` + `flutter test`/`dart test` green (CI at 3.38.10)
- [ ] T045 Run quickstart.md Scenarios 1–5 on real devices via a release-CI build
- [ ] T046 Bump `app/pubspec.yaml` version and matching Inno version in `scripts/compile_windows_exe-inno.iss`; tag `enhanced-v1.1.0` to build+release artifacts

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies — start immediately
- **Foundational (Phase 2)**: depends on Setup — **BLOCKS all user stories** (connection layer + models + tab shell)
- **User Stories (Phase 3–7)**: all depend on Foundational
  - US1 (P1) is the MVP and should land first
  - US2–US5 can then proceed in parallel or in priority order
- **Polish (Phase 8)**: depends on the desired stories being complete

### User Story Dependencies

- **US1 (P1)**: after Foundational. No dependency on other stories. MVP.
- **US2 (P2)**: after Foundational. Independent (browser guests); shares the host session/participant list from Foundational.
- **US3 (P3)**: after Foundational. Builds on the same send path; independently testable.
- **US4 (P4)**: after Foundational. Adds send *sources*; orthogonal to transport.
- **US5 (P5)**: after Foundational. Touches upload handshake + history; independently testable.

### Within Each User Story

- Native/service changes before the pages that call them
- Models before providers before pages
- Core send/receive wiring before progress/polish

### Parallel Opportunities

- Setup: T001, T002 in parallel
- Foundational: T004, T008, T009 in parallel; T005–T007 serialize on the native/service contract
- Once Foundational is done, US1–US5 can be staffed in parallel
- `[P]` unit tests (T012, T029, T039) run independently

---

## Parallel Example: Foundational

```bash
# These touch different files and can run together:
Task: "T004 return AP host IP from WifiDirectPlugin.kt"
Task: "T008 PairingPayload codec in direct_pairing.dart"
Task: "T009 Direct models in model/state/direct/"
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 Setup → 2. Phase 2 Foundational (CRITICAL) → 3. Phase 3 US1
4. **STOP and VALIDATE**: quickstart Scenario 1 on two phones (offline)
5. Demo the offline phone→phone transfer

### Incremental Delivery

- Foundation ready → US1 (MVP, demo) → US2 (browser, demo) → US3 (group, demo)
  → US4 (send anything, demo) → US5 (resume+history, demo)
- Each story is a shippable increment; tag `enhanced-v1.1.0` when the desired
  set is in (T046).

---

## Notes

- `[P]` = different files, no dependency on incomplete work
- The single most important task is **T005** (bind guest traffic to the hotspot) —
  without it transfers silently fail; validate it early.
- Reuse is deliberate: web-send, APK picker, directory picker, QR, and history
  already exist — do not re-implement them.
- Local builds are blocked (NTFS/Rust); CI at Flutter 3.38.10 is the gate.
- Commit after each task or logical group; stop at any checkpoint to validate.
