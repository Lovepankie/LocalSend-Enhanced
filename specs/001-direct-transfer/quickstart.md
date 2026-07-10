# Quickstart: Validating Direct Mode

End-to-end scenarios that prove each user story. These are validation guides, not
implementation. Run against a build produced by the release CI (local builds are
blocked by the machine's NTFS/Rust limitation).

## Prerequisites

- Two Android phones with the app installed (Phase A/C/D/E).
- One computer with any modern browser, no app (Phase B).
- For the strict offline test: mobile data OFF and not pre-joined to any WiFi.

## Scenario 1 — Phone→phone offline transfer (P1)

1. Phone A: open **Direct** tab → **Send** (host). A hotspot starts and a QR appears.
2. Phone B: **Direct** → **Receive** → scan A's QR.
3. Expect: B auto-joins A's hotspot and appears on A as a connected device within
   a few seconds, no WiFi-settings steps.
4. Phone A: pick a file → send. Expect: B receives it; both show completion.
5. Both phones in airplane mode + WiFi on → repeat step 1–4.
   **Pass**: transfer completes with no internet (SC-002), first transfer < 60s (SC-001).

## Scenario 2 — No-app PC web transfer (P2)

1. Phone A: **Direct** → **Send**. Note the shown web address.
2. Computer: join A's hotspot from the OS WiFi list; open the web address in a browser.
3. Expect: a page with **Receive from phone** and **Send to phone**.
4. Drag a file onto **Send to phone** → confirm. **Pass**: phone receives it, it
   appears in history (FR-009).
5. On the phone, offer a file; on the browser choose **Receive** → download.
   **Pass**: file saved via the browser, both directions work in < 90s (SC-003),
   no install.

## Scenario 3 — Group send (P3)

1. Phone A hosts; phones B, C, D (and optionally a browser) all join.
2. A: select a file → **Send to all**.
   **Pass**: every guest receives it; A shows per-device progress/outcomes (SC-004).
3. Mid-transfer, turn off B's WiFi.
   **Pass**: B shows failed/interrupted; C and D still complete (FR-018).

## Scenario 4 — Send folders / albums / apps (P4)

1. A → Direct send → choose a **folder** with subfolders.
   **Pass**: B reconstructs the folder with structure preserved (SC-007).
2. A → choose a **photo/video album**. **Pass**: every item arrives.
3. A → choose an **installed app**. **Pass**: B receives the package and is offered
   installation.

## Scenario 5 — Resume + history (P5)

1. Start a large (multi-GB) transfer A→B.
2. Walk B out of range briefly (or lock B), then return.
   **Pass**: the transfer resumes from where it stopped, not from zero (SC-006).
3. Open **history** on both. **Pass**: sent and received items listed with name,
   size, direction, peer, timestamp.
4. Close and reopen the app → history persists (SC-008); open/re-share a received
   item (FR-021).

## Regression guard

- After any Direct session ends, each device returns to its previous network
  (FR-006) — verify internet works again on both.
- Standard same-network LocalSend transfer still works unchanged.
