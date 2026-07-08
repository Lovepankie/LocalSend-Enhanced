# Contract: No-App Browser Transfer (PC ↔ Phone)

The host serves a browser experience over the same HTTP server used for app
transfers. Download (phone→browser) exists today; upload (browser→phone) is the
new part.

## Served pages (host)

Reuses `send_controller.installRoutes` on the host server:

| Route | Method | Purpose | Status |
|---|---|---|---|
| `/` | GET | Browser UI (index) | exists (download) → extend with upload view |
| `/main.js` | GET | UI script | exists → extend |
| `/i18n.json` | GET | UI strings | exists |
| download endpoints | GET | fetch offered files | exists |
| `ApiRoute.upload.v1` / `v2` | POST | receive files from a client | exists (app) → allow browser origin |

## Browser upload flow (new)

1. Computer joins the hotspot from its OS WiFi list.
2. Opens `webUrl` (`http(s)://host:port`) shown on the host screen.
3. UI shows two actions: **Receive from phone** (existing download) and
   **Send to phone** (new upload view).
4. On send: browser JS performs the prepare-upload handshake then POSTs file
   bodies to `ApiRoute.upload.*`.
5. Within an active Direct session, web-client uploads are **auto-accepted**
   (no per-file prompt) and recorded in history (FR-008/FR-009).

## Constraints

- No sign-in, no install (FR-008). Optional PIN reuses the existing web PIN when
  the host enables it; in Direct Mode the default is frictionless.
- Multiple browser clients may be connected alongside app guests (edge case:
  mixed platforms).
- Uploads honor the same collision-safe receive behavior as the app (FR-014).

## Out of scope (v1)

- Browser as **host**. Browser is always a guest.
- Resumable browser uploads (browser resume deferred; app-to-app resume is P5).
