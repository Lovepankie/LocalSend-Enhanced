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

## Current Branch / Status
**Branch:** `main`
**Status:** COMPLETE — all 6 phases merged to main (PR #7 merged 2026-07-08)

## What Was Built (6 Phases)
1. **Foundation** — init.dart refactor, split into `container_initializer`, `core_initializer`, `desktop_initializer`, `ui_initializer`
2. **Transfer Engine** — parallel uploads (`parallelUploads` setting, `transfer_queue_provider`, manual mapper patch for `settings_state.mapper.dart`)
3. **WiFi Direct P2P** — `wifi_direct_service_factory`, `wifi_direct_page`
4. **UX / Clipboard Sync** — `clipboard_sync_provider`, UI enhancements in `send_tab`
5. **Security / E2E** — `e2e_settings_page`, `audit_log_page`, `audit_log_provider`
6. **CLI / Ecosystem** — `plugin_hook_service`, `plugin_hook_provider`

## CI Notes
- Flutter version locked at `3.38.10` (3.44.1 broke pub get due to mockito/freezed conflict)
- Format job: self-healing `dart format` auto-fix before `--set-exit-if-changed`
- Analyze job: `flutter analyze --no-fatal-infos` (info-level style findings suppressed; errors/warnings still fatal)
- `settings_state.mapper.dart` manually patched (dart_mappable gen not run in CI); if new fields added to SettingsState, patch manually in 6 locations

## Next Steps
- None. Project is complete and on `main`.
- Future: run `dart run build_runner build` to regenerate mapper if SettingsState changes again.
