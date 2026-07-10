# Contract: Group Send (1 → many)

Fan-out of one selection to multiple connected participants within a Direct
session.

## Behavior

- The host send flow lists all connected `Participant`s and offers **Send to all**
  or a subset (FR-016).
- The coordinator (`direct_group_send`) starts **one independent send session per
  selected participant**, reusing the existing single-target send path.
- Sessions run concurrently; the host UI shows **per-device progress and final
  status** (FR-017).
- Failure isolation: a participant dropping or failing marks only that device's
  transfer failed/interrupted; other transfers continue (FR-018).

## Inputs

- `selection`: the set of `TransferItem`s (files/folder/album/app) chosen once.
- `targets`: list of `Participant` ids (or "all").

## Outputs / observable state

Per target: `{ participantId, status ∈ {queued,inProgress,completed,interrupted,failed}, bytesTransferred, total }`.
Aggregate: overall completed/total counts for the host UI.

## Constraints

- No new wire protocol — each per-device session uses the existing transfer
  endpoints (research §8).
- Group size ceiling ~8 (assumption); additional joiners are queued/refused
  gracefully (edge case).
- A single failed device never blocks or aborts the group (FR-018).
