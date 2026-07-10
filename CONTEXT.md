# LocalSend-Enhanced — Project Context

## Purpose
Fork of LocalSend with 6 improvement phases for RincolTech Solutions. Enhanced local file-sharing app with WiFi Direct P2P, parallel uploads, E2E encryption, clipboard sync, audit logs, and plugin hook CLI ecosystem.

## Stack
- Flutter/Dart (app), Dart (common package)
- Riverpod (refena_flutter) state management
- dart_mappable for serialization
- rhttp for HTTP, Rust (cargokit) for native
- GitHub Actions CI (Flutter 3.38.10 stable)

## Repo
`https://github.com/RincolTech-Solutions-ltd/LocalSend-Enhanced`

## Active Feature — Direct Mode (branch `001-direct-transfer`, PR #11)
Xender/SHAREit-class offline hotspot transfer. SpecKit-driven
(`specs/001-direct-transfer/`: spec, plan, research, data-model, contracts,
tasks). Status as of 2026-07-08: US1-US5 implemented (resume deferred), all
CI-green, final test APK building.

- **US1** offline phone↔phone: `WifiDirectPlugin.kt` returns SoftAP host IP +
  binds guest traffic (`bindProcessToNetwork`); host QR is `lsd://` pairing
  payload (host IP+port+token); guest scans (`mobile_scanner`) → joins → binds →
  registers host directly via `StartFavoriteScan` (multicast unreliable on
  local-only hotspot). `PairingPayload` codec in `provider/direct/`.
- **US2** no-app PC: `DirectWebController` serves `GET /direct` (browser upload
  page) + `POST /direct/upload` (multipart→saveFile). Download side pre-existed.
- **US3** group send: `WifiDirectNotifier.sendToAllConnected()` fan-out,
  failure-isolated; "Send to all" button in host view.
- **US4** folders/albums/apps: work via existing send flow once connected.
- **US5** history: browser uploads recorded via `AddHistoryEntryAction`;
  app-to-app already recorded. **Resume (byte-offset) deferred** — needs
  on-device testing.
- **Key files**: `provider/network/wifi_direct_provider.dart`,
  `pages/wifi_direct/wifi_direct_page.dart`, `provider/direct/direct_pairing.dart`,
  `provider/network/server/controller/direct_web_controller.dart`,
  `android/.../WifiDirectPlugin.kt`.
- **CI gap learned**: PR CI (dart analyze/test) does NOT compile Kotlin or build
  the APK — native bugs only surface in the Build Artifacts (APK) workflow. Run
  an APK build to validate any native/Kotlin change. (A KDoc `*/` bug slipped
  past PR CI and was caught by the APK build.)
- **Next**: on-device test on two phones → then merge to main + tag
  `enhanced-v1.1.0`. Deferred: transfer resume, iOS host.

## Shipped Status (main)
**Branch:** `main`
**Status:** SHIPPED — all 6 phases merged to main, plugin hooks fully wired, release tagged `enhanced-v1.0.0` (2026-07-08)
- PR #7 — all 6 phases (staging → main)
- PR #8 — plugin hooks wired end-to-end (persist + fire on receive)
- PR #9 — build-artifacts CI workflow (APK + Linux bundle)
- Tag `enhanced-v1.0.0` triggers the release build → downloadable APK + Linux bundle attached to a GitHub Release

## What Was Built (6 Phases)
1. **Foundation** — init.dart refactor, split into `container_initializer`, `core_initializer`, `desktop_initializer`, `ui_initializer`
2. **Transfer Engine** — parallel uploads (`parallelUploads` setting, `transfer_queue_provider`, manual mapper patch for `settings_state.mapper.dart`)
3. **WiFi Direct P2P** — `wifi_direct_service_factory`, `wifi_direct_page`
4. **UX / Clipboard Sync** — `clipboard_sync_provider`, UI enhancements in `send_tab`
5. **Security / E2E** — `e2e_settings_page`, `audit_log_page`, `audit_log_provider`
6. **CLI / Ecosystem** — `plugin_hook_service`, `plugin_hook_provider`. Hooks now **persist** (`PersistenceService.getHooks()/setHooks()`, key `ls_receive_hooks`) and **fire on actual receive** via `receive_controller` → `PluginHookService.fireOnReceive()` at the file-saved point (fire-and-forget). Previously config-only/in-memory.

## Build & Release (important — local build is blocked)
- **Local builds fail** on this machine: the "New Volume" repo and `~/.cargo` are NTFS `fuseblk` mounts that don't honor exec bits, so Rust (`rhttp`) and `gradlew` can't execute. Local Flutter is also 3.44.1 (deps only resolve on CI's 3.38.10).
- **Ship via CI:** the `Build Artifacts` workflow (`.github/workflows/build-artifacts.yml`) builds on cloud runners. Trigger by pushing a `v*` / `enhanced-v*` tag (or run manually). It self-generates an ephemeral keystore (no repo secrets) and attaches split-per-ABI APKs + a Linux `.tar.gz` to a GitHub Release.
- To build an APK locally you'd need an ext4 working copy + Rust toolchain on ext4.

## CI Notes
- Flutter version locked at `3.38.10` (3.44.1 broke pub get due to mockito/freezed conflict)
- Format job: self-healing `dart format` auto-fix before `--set-exit-if-changed`
- Analyze job: `flutter analyze --no-fatal-infos` (info-level style findings suppressed; errors/warnings still fatal)
- `settings_state.mapper.dart` manually patched (dart_mappable gen not run in CI); if new fields added to SettingsState, patch manually in 6 locations

## Next Steps
- None required. Product is complete, on `main`, and released as `enhanced-v1.0.0`.
- To cut a new release: bump `app/pubspec.yaml` version, push a new `enhanced-vX.Y.Z` tag → artifacts build automatically.
- Future: run `dart run build_runner build` to regenerate the mapper if SettingsState changes again (removes the manual patch).
