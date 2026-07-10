# Phase 0 Research: Direct Mode

Technical decisions that resolve the unknowns in the plan's Technical Context.
Each is stated as Decision / Rationale / Alternatives.

## 1. Host access-point IP on a local-only hotspot (Android)

- **Decision**: After `WifiManager.startLocalOnlyHotspot()` succeeds, resolve the
  host's own IPv4 on the SoftAP/tether interface natively (enumerate
  `NetworkInterface`s, pick the non-loopback address on the `ap*`/`swlan*`/tether
  interface, typically `192.168.x.1`) and return it in the `startHotspot`
  channel result alongside SSID + passphrase.
- **Rationale**: The `LocalOnlyHotspotReservation` exposes credentials but not the
  gateway IP. Guests need a concrete host IP to connect directly (multicast is
  unreliable on this link — see §5). The AP host is always the subnet gateway.
- **Alternatives**: Hardcode `192.168.43.1`/`192.168.49.1` — rejected, the
  address varies by OEM/Android version. Have the guest infer the gateway from
  DHCP — workable but redundant once the host advertises it in the QR.

## 2. Binding the guest's traffic to the hotspot network

- **Decision**: Join via `WifiNetworkSpecifier` + `ConnectivityManager.requestNetwork`
  (API 29+), hold the returned `Network`, and call
  `ConnectivityManager.bindProcessToNetwork(network)` so all app HTTP traffic
  routes over the direct link. Restore with `bindProcessToNetwork(null)` on
  leave/teardown.
- **Rationale**: A local-only hotspot has no internet, so Android's default
  routing sends app traffic elsewhere (mobile data / other WiFi). Without an
  explicit bind, the transfer silently fails — this is the single most important
  fix for the whole feature.
- **Alternatives**: Per-socket `Network.bindSocket()` — more precise but invasive
  across the isolate HTTP stack; deferred. `setProcessDefaultNetwork` (deprecated)
  — rejected.

## 3. Auto-join mechanism

- **Decision**: Primary path is `WifiNetworkSpecifier` via `requestNetwork` (API
  29+): one system consent, then automatic connect. For API 26–28, fall back to
  a guided manual join (show SSID/password + deep-link to WiFi settings).
- **Rationale**: `WifiNetworkSpecifier` is the supported programmatic join on
  modern Android and needs no location-scan permission dance. Manual fallback
  keeps older devices usable (spec FR-024).
- **Alternatives**: `WifiManager.addNetwork()` (deprecated on API 29+) — rejected.
  `WifiNetworkSuggestion` — non-deterministic timing, unsuitable for an immediate
  in-session join.

## 4. QR pairing payload

- **Decision**: Encode a single LocalSend-Direct payload as a custom URI
  `lsd://v1/<base64url(json)>` where the JSON carries: `ssid`, `password`,
  `host` (IP from §1), `port`, `protocol` (http|https), optional `fingerprint`,
  and a short-lived `sessionToken`. The host screen also shows a standard
  `WIFI:T:WPA;S:..;P:..;;` code for camera-app join as a fallback.
- **Rationale**: One scan should do both — join the hotspot *and* locate the host
  — so pairing is truly one-step (spec FR-003/FR-004). Base64 JSON is
  extensible for later fields.
- **Alternatives**: Two separate QRs (WiFi + connect) — worse UX, rejected.
  Reuse only the standard `WIFI:` QR — insufficient, it can't carry host IP/port.

## 5. Peer discovery over the direct link

- **Decision**: Do **not** rely on multicast discovery on the hotspot. The guest,
  knowing `host:port` from the QR, directly calls the existing register/announce
  endpoint (reuse `scan_facade` / the register path used by
  `nearby_devices_provider`) to present itself; the host adds it as a connected
  participant. The host similarly knows guests as they register.
- **Rationale**: Multicast UDP (224.0.0.167:53317) is frequently dropped on
  local-only hotspots and across some OEM AP implementations. Direct registration
  to a known IP is deterministic and reuses existing code.
- **Alternatives**: Keep multicast with retries — flaky, rejected. mDNS — extra
  dependency, same routing risk.

## 6. QR scanning dependency

- **Decision**: Add `mobile_scanner` for the guest scan screen (camera → decode
  the `lsd://` / `WIFI:` payload). Generation stays on the existing
  `pretty_qr_code`.
- **Rationale**: The repo has QR *generation* only; no scanner is wired.
  `mobile_scanner` is actively maintained, MLKit/zxing-backed, supports
  Android/iOS/desktop-camera, and integrates cleanly with a Flutter camera view.
- **Alternatives**: `qr_code_scanner` — less maintained / plugin API churn,
  rejected. Manual-code-only (no camera) — fails SC-009's scan-first goal.

## 7. Browser upload (PC → phone), completing P2

- **Decision**: The existing `send_controller` web routes serve a download-only
  browser UI (`Assets.web.index`). Extend the served web app with an **upload**
  view whose JS POSTs files to the existing upload route
  (`ApiRoute.upload.v1/v2`, via the prepare-upload handshake). Within an active
  Direct session, browser-originated uploads are auto-accepted and recorded in
  history (spec FR-008/FR-009).
- **Rationale**: The transfer protocol and receive pipeline already exist; only
  the browser-facing HTML/JS + an auto-accept path for web clients are missing.
  Reuses the receiver end-to-end.
- **Alternatives**: A separate bespoke multipart endpoint just for browsers —
  duplicates receive logic, rejected. WebRTC data channel from browser — the repo
  has WebRTC but it's overkill for same-LAN upload, deferred.

## 8. Group send fan-out (P3)

- **Decision**: A `direct_group_send` coordinator starts one existing send
  session per selected participant, concurrently, tracking per-device progress
  and isolating failures (one guest dropping does not abort the others).
- **Rationale**: The send session already handles a single target robustly;
  fanning out N independent sessions is the simplest correct design and satisfies
  FR-016/FR-017/FR-018 without a new protocol.
- **Alternatives**: A single push to a multicast group — large new protocol, no
  per-device control, rejected.

## 9. Resume interrupted transfers (P5)

- **Decision**: Extend the prepare-upload handshake so the receiver reports
  `receivedBytes` per (session,file); the sender seeks to that offset and streams
  the remainder. Scope v1 to resume within the same Direct session/connection.
- **Rationale**: Minimal protocol delta on top of the existing upload flow;
  covers the common "walked out of range / screen locked" case (SC-006).
- **Alternatives**: Full cross-restart resumable uploads with a durable manifest —
  valuable but larger; deferred beyond v1.

## 10. Sending folders, albums, and installed apps (P4)

- **Decision**: Reuse existing pieces as Direct send sources: directory picker
  (`pick_directory_path`) for folders (send with relative paths preserved), the
  media/album selection already used by the send tab, and `apk_picker_page` for
  installed apps (extract package → send `.apk`; receiver offers install via the
  existing open/install intent).
- **Rationale**: All three sources already exist; Direct Mode only needs to
  surface them in its send flow and ensure structure/metadata survive (FR-011..013).
- **Alternatives**: New pickers — duplicative, rejected.

## Cross-cutting: teardown & network restoration

- **Decision**: Ending a session (host stop or guest leave) tears down the
  hotspot / releases the requested network and calls
  `bindProcessToNetwork(null)`, restoring prior connectivity (FR-006).
- **Rationale**: Users must return to their normal network after sharing; leaking
  a bound no-internet network would break the phone's connectivity.

## Open items deferred beyond v1 (recorded, not blocking)

- iOS as **host** (local hotspot creation) — guests only for now.
- Desktop as **host** — spec scopes host = Android.
- Cross-restart resumable transfers (see §9).
- End-to-end cryptographic peer identity beyond hotspot credential protection.
