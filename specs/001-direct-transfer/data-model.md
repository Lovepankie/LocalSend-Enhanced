# Phase 1 Data Model: Direct Mode

Entities are described conceptually (fields + relationships + states). Concrete
Dart classes/mappers are produced in the implementation phase; models follow the
existing `dart_mappable` conventions used across the app.

## DirectSession (host side)

Represents an active hosting session from hotspot-up to teardown.

| Field | Type | Notes |
|---|---|---|
| id | String | session id (uuid) |
| role | enum {host} | host-only in v1 |
| ssid | String | hotspot network name |
| password | String | hotspot passphrase |
| hostIp | String | AP gateway IP (research §1) |
| port | int | transfer/web port |
| protocol | enum {http, https} | matches server config |
| webUrl | String | `http(s)://hostIp:port` for browser guests |
| sessionToken | String | short-lived join/auth token |
| participants | List\<Participant\> | connected devices |
| state | enum | see state machine below |
| startedAt | DateTime | |

**State machine**: `starting → waiting → active → ending → ended`
(`error` reachable from `starting`/`active`). `active` once ≥1 participant is
connected; `ending` tears down hotspot and restores network.

## GuestConnection (guest side)

Represents the guest's view of joining a host.

| Field | Type | Notes |
|---|---|---|
| ssid / password | String | from scanned payload |
| hostIp / port / protocol | — | target for direct registration |
| sessionToken | String | presented to host on register |
| boundNetwork | opaque handle | the bound `Network` (research §2) |
| state | enum | `scanning → joining → binding → registering → connected → left / error` |

## Participant

A device connected to a `DirectSession`.

| Field | Type | Notes |
|---|---|---|
| id | String | device id |
| displayName | String | alias/model |
| platform | enum {phoneApp, browser, desktopApp} | |
| ip | String | peer IP on the hotspot subnet |
| connectionState | enum {connected, transferring, disconnected} | |
| currentProgress | double? | for in-flight transfer |

**Relationship**: `DirectSession 1—* Participant`.

## TransferItem

A unit queued/in-flight in a Direct transfer (extends the concept the existing
send/receive pipeline already moves).

| Field | Type | Notes |
|---|---|---|
| id | String | |
| name | String | file / entry name |
| size | int | bytes |
| type | enum {file, folderEntry, albumItem, appPackage} | P4 source types |
| relativePath | String? | preserves folder structure (FR-011) |
| direction | enum {send, receive} | |
| status | enum {queued, inProgress, interrupted, failed, completed} | |
| bytesTransferred | int | drives resume (research §9) |
| targetParticipantId | String? | for group send per-device tracking |

**State machine**: `queued → inProgress → completed`; `inProgress → interrupted`
(resumable) or `→ failed`.

## TransferRecord (history, persisted)

Persisted across restarts via `PersistenceService` (reuses/extends the existing
receive-history storage; adds sent items and Direct metadata).

| Field | Type | Notes |
|---|---|---|
| id | String | |
| name | String | |
| size | int | |
| direction | enum {send, receive} | |
| peerName | String | other device |
| timestamp | DateTime (UTC) | |
| savedPath | String? | for received items (open/re-share) |
| status | enum {completed, interrupted, failed} | |
| via | enum {direct, standard} | distinguishes Direct Mode transfers |

**Relationship**: history is append-only; a completed/interrupted `TransferItem`
produces one `TransferRecord`.

## PairingPayload (QR contract — see contracts/qr-pairing.md)

Transport object encoded into the QR: `{ v, ssid, password, host, port,
protocol, fingerprint?, sessionToken }`. Decoded by the guest to drive
GuestConnection.

## Validation rules (from requirements)

- `password` length and `ssid` presence required before a QR is shown (FR-002).
- `hostIp`/`port` must be resolved before the session enters `waiting` (FR-003).
- Name collisions on receive are disambiguated, never silently overwritten (FR-014).
- A participant must present a valid `sessionToken` to be admitted (FR-026); host
  can remove any participant (FR-025).
- Receiver must verify sufficient storage before accepting an item (edge cases).
