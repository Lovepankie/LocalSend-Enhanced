# Contract: QR Pairing Payload

The single artifact a guest scans to both join the hotspot and locate the host.

## Primary payload (LocalSend-Direct)

URI form: `lsd://v1/<base64url(json)>`

JSON (before base64url):

```json
{
  "v": 1,
  "ssid": "LocalSend-AB12",
  "password": "8-char-or-longer",
  "host": "192.168.49.1",
  "port": 53317,
  "protocol": "http",
  "fingerprint": "optional-tls-fingerprint",
  "sessionToken": "short-lived-token"
}
```

Field rules:

- `v` — payload version; consumers reject unknown major versions gracefully.
- `ssid` / `password` — hotspot credentials; used to join (research §3).
- `host` / `port` — where the guest registers and transfers (research §5).
- `protocol` — `http` or `https`; must match the host server.
- `fingerprint` — present only when `protocol=https`; guest pins it.
- `sessionToken` — presented on register; host admits only valid tokens (FR-026).

## Fallback payload (camera-app join)

A standard WiFi QR is also displayed so a stock camera can at least join the
network: `WIFI:T:WPA;S:<ssid>;P:<password>;;`. After a camera-app join the user
opens the app and enters/join via the shown short code.

## Guest decode flow

1. Scan → if URI starts `lsd://` decode base64url→JSON (primary path).
2. Else if starts `WIFI:` → parse SSID/password only (fallback; host located via
   manual short code).
3. Join hotspot (research §2/§3) → bind network → register at
   `host:port` with `sessionToken` → session `connected`.

## Manual fallback (no camera)

Host shows: network name, password, and a short numeric code that encodes/maps to
`host:port`+token so a guest can join from OS WiFi settings then type the code.

## Backward/compat

Extends the existing `HotspotCredentials.toQrPayload()` (which currently emits
only the `WIFI:` string). `toQrPayload()` gains the `lsd://` primary output;
`fromQrPayload()` learns to parse both.
