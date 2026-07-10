# Feature Specification: Direct Mode — Hotspot File Transfer

**Feature Branch**: `001-direct-transfer`

**Created**: 2026-07-08

**Status**: Draft

**Input**: User description: "Direct Mode — an offline, hotspot-based direct file transfer experience (Xender/SHAREit class) inside LocalSend-Enhanced. A host device creates a local-only WiFi hotspot (no internet) and shows a QR; guests (phones or PCs) join and transfer files directly with no router and no internet. Includes no-app PC web transfer, group send, sending folders/albums/apps, and resume + history. Presented as a dedicated Direct tab."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Phone-to-phone direct transfer via QR (Priority: P1)

Two people are together with no WiFi network and no mobile data (or they simply don't want to use data). One opens the **Direct** tab and taps **Send** (host): the phone creates a private local hotspot and shows a large QR code. The other opens **Direct** and taps **Receive**, scans the QR, and their phone automatically joins the host's hotspot and connects. The sender picks files and they transfer directly, fast, over the local WiFi link. No router, no internet, no account.

**Why this priority**: This is the core Xender loop and the whole reason for the feature. If only this ships, the product already delivers its headline value: offline, direct, fast phone-to-phone sharing.

**Independent Test**: With both phones in airplane mode + WiFi on, a host can start Direct, a guest can scan the QR, join, and receive a chosen file end-to-end — proving the offline direct path works with zero network infrastructure.

**Acceptance Scenarios**:

1. **Given** the host phone has no internet connection, **When** the user taps Send in the Direct tab, **Then** a private hotspot is created that does not provide internet and a QR code is displayed.
2. **Given** a guest phone with the app, **When** the guest scans the host's QR code, **Then** the guest automatically joins the host's hotspot and appears as a connected device on the host within a few seconds, with no manual WiFi-settings steps.
3. **Given** the guest is connected, **When** the host selects one or more files and confirms sending, **Then** the files are received on the guest and both sides show completion.
4. **Given** a transfer is in progress, **When** it completes, **Then** the host may end the session and the hotspot is torn down, restoring the phone's prior network state.

---

### User Story 2 - No-app PC / laptop web transfer (Priority: P2)

A person wants to move files between a phone and a computer that does not have the app installed. The phone hosts a Direct session and shows both a QR and a simple web address (for example `http://<host>:<port>`). The computer joins the phone's hotspot from its WiFi list, opens the address in any browser, and sees a clean page where it can drag files to send to the phone or download files the phone is offering — all without installing anything.

**Why this priority**: This is the killer "works with any computer" capability. It removes the biggest friction (installing software on a borrowed or locked-down PC) and covers the phone-to-PC direction the user requires.

**Independent Test**: A laptop with no app installed joins the phone's hotspot, opens the shown URL in a browser, uploads a file to the phone and downloads a file from the phone — proving the browser-only path works both directions.

**Acceptance Scenarios**:

1. **Given** a host phone running Direct, **When** the user views the join screen, **Then** a human-readable web address is shown alongside the QR.
2. **Given** a computer joined to the hotspot, **When** it opens the shown address in a browser, **Then** it sees a page to send files to the phone and to download files the phone is sharing, with no install or sign-in.
3. **Given** the browser page, **When** the user drags one or more files onto it and confirms, **Then** those files are received on the phone and appear in its transfer history.
4. **Given** the phone is offering files, **When** the browser user selects and downloads them, **Then** the files are saved on the computer through the normal browser download flow.

---

### User Story 3 - Group send, one host to many guests (Priority: P3)

One person has photos or a file everyone in the room wants. They host a Direct session; several friends join the same hotspot by scanning the QR. The host selects the files once, picks the connected devices (or "all"), and sends to everyone at the same time.

**Why this priority**: A common real-world moment (sharing event photos with a group) and a clear differentiator over one-to-one tools. It builds directly on the P1 connection model.

**Independent Test**: Three or more guests join one host; the host sends a file to "all" in one action and every guest receives it.

**Acceptance Scenarios**:

1. **Given** multiple guests joined to the host, **When** the host opens the send flow, **Then** all connected devices are listed and selectable, including a "send to all" option.
2. **Given** several devices are selected, **When** the host confirms sending, **Then** each selected device receives the files and the host sees per-device progress and completion.
3. **Given** a group send in progress, **When** one guest disconnects, **Then** that device's transfer is marked failed/interrupted while the others continue unaffected.

---

### User Story 4 - Send anything: folders, albums, and installed apps (Priority: P4)

Beyond single files, the user wants to send a whole folder, an entire photo/video album, or share an app that's already installed on their phone (so a friend can install the same app offline). From the Direct send flow they choose one of these sources and everything transfers with its structure intact.

**Why this priority**: Matches user expectations set by Xender/SHAREit (albums and app-sharing are heavily used) and greatly increases everyday usefulness. It is additive on top of the transfer path from P1–P3.

**Independent Test**: The host selects a photo album (multiple items), a nested folder, and an installed app; each is sent and arrives complete — the album as its images, the folder with its structure, the app as an installable package.

**Acceptance Scenarios**:

1. **Given** the send flow, **When** the user chooses a folder, **Then** all files within it (including subfolders) are transferred and reconstructed on the receiver with their relative structure.
2. **Given** the send flow, **When** the user chooses a photo/video album, **Then** every item in that album is transferred.
3. **Given** the send flow, **When** the user chooses an installed app to share, **Then** the app's installable package is transferred and the receiver can choose to install it.
4. **Given** a large multi-item selection, **When** sending, **Then** the user sees overall progress and per-item status.

---

### User Story 5 - Resume interrupted transfers and view history (Priority: P5)

Transfers of big videos sometimes get interrupted (someone walks out of range, a phone locks). The user wants an interrupted transfer to resume rather than restart, and wants a persistent record of what was sent and received, with the ability to re-open or re-share received items.

**Why this priority**: Reliability and trust for large transfers, plus convenience. Valuable but the feature is usable without it, so it is lowest priority for the first version.

**Independent Test**: Start a large transfer, interrupt it (move out of range briefly / lock screen), restore proximity, and confirm the transfer continues from where it stopped; then confirm both sent and received items appear in a persistent history after the app is restarted.

**Acceptance Scenarios**:

1. **Given** a transfer that was interrupted before completion, **When** the connection is restored within the same session, **Then** the transfer resumes from the last completed point rather than restarting from zero.
2. **Given** completed transfers, **When** the user opens history, **Then** they see a persistent list of sent and received items with names, sizes, direction, peer, and timestamp.
3. **Given** a received item in history, **When** the user selects it, **Then** they can open it or re-share it.
4. **Given** the app is closed and reopened, **When** the user opens history, **Then** previously recorded transfers are still present.

---

### Edge Cases

- **No hotspot capability**: On a device that cannot create a local hotspot, the Send/host action explains the limitation and offers the standard same-network transfer instead.
- **Guest already on another WiFi**: Joining the host hotspot must clearly switch the guest to the direct link for the duration of the transfer and restore the prior network afterward.
- **Internet expectation**: While joined to the host hotspot, guests have no internet; the app should make clear this is expected (it is a direct link, not an access point to the web).
- **QR scan failure / camera denied**: A manual fallback (network name + password, or a short code) lets the guest join without the camera.
- **Host leaves or ends session mid-transfer**: In-flight transfers are marked interrupted on both sides and can be resumed or retried.
- **Duplicate / same-named files on receiver**: Receiver avoids silently overwriting; it disambiguates or asks.
- **Very large group**: Beyond a supported number of simultaneous guests, additional join attempts are queued or politely refused rather than degrading everyone.
- **Insufficient storage on receiver**: The receiver detects it cannot fit an incoming transfer and refuses/aborts cleanly with a clear message.
- **Mixed platforms**: A PC joining via browser and a phone joining via app can be part of the same host session without conflict.
- **Permission gaps**: If location/nearby-devices or storage permissions needed for hotspot or file access are denied, the app explains what is needed and how to grant it.

## Requirements *(mandatory)*

### Functional Requirements

**Hosting & pairing**

- **FR-001**: The system MUST let a user start a Direct session as host, creating a local-only wireless hotspot that does not route to the internet.
- **FR-002**: The host MUST display a QR code and a human-readable fallback (network name + password or short code) that a guest can use to join.
- **FR-003**: The QR/pairing data MUST contain everything a guest needs to both join the hotspot and locate the host for transfer, so joining is automatic after scanning.
- **FR-004**: A guest scanning the host's QR MUST automatically connect to the host's hotspot and register with the host without manual OS-level WiFi configuration.
- **FR-005**: While joined, a guest's file-transfer traffic MUST be directed over the host's direct link rather than any other available network.
- **FR-006**: Ending a Direct session MUST tear down the hotspot and restore each device's prior network state.

**Web (no-app) transfer**

- **FR-007**: The host MUST expose a browser-accessible address so a computer joined to the hotspot can transfer without installing the app.
- **FR-008**: The browser experience MUST allow sending files to the host and downloading files the host is sharing, both directions, with no sign-in or install.
- **FR-009**: Files received from a browser client MUST appear in the host's transfer history like any other received item.

**Transfer content**

- **FR-010**: Users MUST be able to send one or more individual files.
- **FR-011**: Users MUST be able to send a folder, preserving its internal structure on the receiver.
- **FR-012**: Users MUST be able to send an entire photo/video album selection.
- **FR-013**: Users MUST be able to share an installed application as an installable package that the receiver can choose to install.
- **FR-014**: Receivers MUST handle name collisions without silent data loss.

**Group send**

- **FR-015**: A host MUST support multiple guests connected to one Direct session simultaneously.
- **FR-016**: A host MUST be able to send a selection to multiple connected devices (including "all") in a single action.
- **FR-017**: The host MUST show per-device progress and completion/failure for a group send.
- **FR-018**: One guest failing or disconnecting MUST NOT abort transfers to the other guests.

**Reliability & history**

- **FR-019**: An interrupted transfer MUST be able to resume from the last completed point when the connection is restored within the session, rather than restarting.
- **FR-020**: The system MUST keep a persistent history of sent and received items surviving app restarts, including name, size, direction, peer, and timestamp.
- **FR-021**: Users MUST be able to open or re-share a received item from history.

**Presentation & feedback**

- **FR-022**: The feature MUST be presented as a dedicated "Direct" area in the app with a prominent Send (host) and Receive (join/scan) entry point and QR display.
- **FR-023**: The system MUST show clear status throughout (creating hotspot, waiting for guests, connected devices, transfer progress, completion, errors).
- **FR-024**: When a required capability or permission is unavailable (no hotspot support, denied permission, no camera), the system MUST explain the limitation and offer a fallback path where one exists.

**Trust & safety (local session)**

- **FR-025**: The host MUST be able to see which devices are connected and MUST be able to remove/deny a connected device.
- **FR-026**: The direct link MUST be protected such that only devices with the host's pairing credentials can join the hotspot.

### Key Entities *(include if feature involves data)*

- **Direct Session**: A hosting session with a lifetime from start to teardown. Attributes: host device identity, pairing credentials (network name/password + short code), web address, list of connected participants, state (starting, waiting, active, ending).
- **Participant**: A device connected to a Direct session. Attributes: display name, platform (phone-app / browser), connection state, per-transfer progress.
- **Transfer Item**: A unit being sent/received. Attributes: name, size, type (file / folder-entry / album-item / app-package), source, direction, status (queued, in-progress, completed, interrupted, failed), progress.
- **Transfer Record (History)**: A persisted record of a completed or interrupted item. Attributes: name, size, direction, peer, timestamp, resulting location (for received items), status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Starting from the Direct tab, a first-time pair of users can complete their first phone-to-phone transfer (host start → guest scan → file received) in under 60 seconds, with no network setup steps.
- **SC-002**: The offline path works with both devices having no internet (mobile data off, not on any WiFi network beforehand) — a transfer completes successfully.
- **SC-003**: A computer with no app installed can send a file to the phone and download a file from the phone using only a browser, in under 90 seconds from joining the hotspot.
- **SC-004**: A host can transfer a single selection to at least 4 guests at once, and every guest receives it, with the host seeing per-device outcomes.
- **SC-005**: Direct transfer throughput over the hotspot link is at least several times faster than transferring the same content over a typical shared internet connection (i.e., limited by local WiFi, not the internet).
- **SC-006**: An interrupted large transfer resumes and completes without re-sending already-delivered content once the connection is restored within the session.
- **SC-007**: Sending a folder or album reproduces 100% of its items on the receiver, with folder structure preserved.
- **SC-008**: Transfer history persists across app restarts and correctly reflects every sent and received item from the session.
- **SC-009**: At least 90% of guests can join by scanning the QR on the first attempt without resorting to the manual fallback.

## Assumptions

- **Host is Android**: The device that creates the hotspot is an Android phone (local hotspot creation is an Android capability in scope). iPhones and desktops participate as guests, not hosts, in this version.
- **Guests are Android phones (app) or computers (browser)**: iOS guests are not a target for this version and may be addressed later.
- **Local trust model**: A Direct session is a short-lived, in-person, trusted context. Devices that present the host's pairing credentials are allowed to join; the host retains the ability to see and remove connected devices. Full end-to-end cryptographic identity between peers is out of scope for this version beyond protecting the hotspot itself.
- **Reuses existing transfer engine**: Once devices share the direct link, the app's existing file-transfer mechanism handles the actual sending; Direct Mode provides the connection, pairing, presentation, and the added content types.
- **Builds on existing WiFi Direct scaffolding**: This feature completes and productizes the previously scaffolded hotspot capability rather than starting from nothing.
- **App-sharing scope**: "Share an installed app" covers user-installed apps whose package can be read; system apps or protected packages may be excluded.
- **Group size**: A reasonable simultaneous-guest ceiling (on the order of 8) is assumed for the first version; beyond it, joins are queued or refused gracefully.
- **Storage & permissions**: Guests/receivers have permission to save incoming files and sufficient storage; the app checks and reports when they don't.
- **Constitution**: The project constitution is currently an unpopulated template; this spec follows general quality/testability principles until the constitution is ratified.
