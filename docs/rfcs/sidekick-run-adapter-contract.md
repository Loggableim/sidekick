# Sidekick Run Adapter Compatibility Contract

- **Status:** Proposed
- **Author:** @Michaelyklam
- **Created:** 2026-05-11
- **Tracking issue:** [#1925](https://github.com/nesquena/hermes-webui/issues/1925)

## Problem

Sidekick currently gives a rich workbench experience, but browser-originated
chat turns are still executed inside the WebUI server process. The WebUI path
creates process-local stream state, starts background agent threads, constructs or
reuses `AIAgent`, and owns callback queues for token, tool, reasoning, approval,
and clarify state.

The target boundary from #1925 is:

> WebUI should be thin in execution ownership, not thin in product scope.

That means WebUI remains the full browser workbench for sessions, workspace
files, chat rendering, tools, approvals, status, diagnostics, and controls. The
change is that Nova must own run lifecycle, event ordering, replay,
approvals, clarify, cancellation, and terminal state.

This document defines the first reviewable contract for a Sidekick-owned run
adapter. It is intentionally a spec/gap matrix, not an implementation plan for a
new WebUI runtime surrogate.

## Goals

- Keep the browser-facing WebUI workbench contract stable while execution moves
  out of the WebUI process.
- Define the minimum Sidekick Runtime API / IPC v0 surface WebUI needs before it
  can route new runs to Sidekick-owned execution.
- Map current WebUI-owned runtime primitives to Sidekick-owned APIs, WebUI
  presentation state, or explicit temporary compatibility shims.
- Make restart/reattach the first meaningful success criterion, not merely
  "basic chat streamed once."

## Non-goals

- Do not implement the adapter in this RFC.
- Do not create a new run-manager sidecar or broker requirement.
- Do not re-create `STREAMS`, cached `AIAgent` objects, approval queues, clarify
  queues, or cancellation flags under new names inside WebUI.
- Do not reduce WebUI product scope. The rich workbench UX remains in WebUI.
- Do not require every event to be durably persisted on day one if the first
  upstream runtime slice can still prove Sidekick-owned execution and reconnect.

## Ownership boundary

### Nova owns

- run creation and lifecycle
- run ids and session-to-active-run mapping
- ordered event stream and replay cursor
- terminal run state, final result, and error metadata
- model/provider/profile/toolset routing
- agent execution and tool dispatch
- command semantics and capability metadata
- approval and clarify lifecycle
- cancel, interrupt, queue, continue, steer, and goal control where supported
- durable runtime/session state needed for reconnect

### WebUI owns

- browser authentication and presentation-specific session routing
- chat layout, transcript rendering, tool cards, thinking/progress display
- approval and clarify widgets
- workspace/file-panel UX
- settings/admin/diagnostics presentation
- adapting Sidekick runtime events into WebUI-compatible browser events
- temporary compatibility shims explicitly listed in this RFC

## WebUI event/control compatibility contract

The browser-facing contract should remain stable enough that the current WebUI
workbench can render either the legacy in-process runtime or the Sidekick-owned run
adapter during migration. These are presentation events over Sidekick runtime
truth, not a second source of truth.

All events should include enough metadata for idempotent rendering and
reconnect:

```json
{
  "event_id": "run_123:42",
  "seq": 42,
  "run_id": "run_123",
  "session_id": "20260511_...",
  "type": "tool.update",
  "created_at": 1778540000.0,
  "terminal": false,
  "payload": {}
}
```

`event_id` may be an SSE `id:` value or an equivalent cursor token. `seq` is a
monotonic per-run cursor. Clients may send `Last-Event-ID` or `after_seq` on
reconnect. The runtime should treat replay as at-least-once delivery; WebUI must
deduplicate by `run_id` + `seq` / `event_id`.

### Event families

| WebUI event family | Required payload | Runtime source of truth |
|---|---|---|
| `run.started` / `status` | lifecycle state, controls available, session id, workspace/profile/model/toolset summary | Sidekick run state |
| `token.delta` | assistant message id/segment id, delta text, optional content type | Nova model output stream |
| `reasoning.delta` / `reasoning.done` | reasoning text or structured reasoning block, visibility metadata | Sidekick reasoning callback/event stream |
| `progress` | concise status/progress text, optional phase/tool context | Nova agent progress callbacks |
| `tool.started` | tool call id, tool name, sanitized arguments, start time | Sidekick tool dispatch lifecycle |
| `tool.updated` | stdout/stderr/structured partial data, progress metadata | Sidekick tool dispatch lifecycle |
| `tool.done` | result, exit/status, duration, error flag | Sidekick tool dispatch lifecycle |
| `approval.requested` | approval id, command/action summary, risk metadata, available choices | Sidekick approval queue/control plane |
| `approval.resolved` | approval id, choice, resulting status | Sidekick approval queue/control plane |
| `clarify.requested` | clarify id, question, choices/input mode | Sidekick clarify lifecycle |
| `clarify.resolved` | clarify id, answer metadata/status | Sidekick clarify lifecycle |
| `title.updated` | title text, title source/confidence | Nova session/title subsystem |
| `usage.updated` / `usage.final` | tokens, cost, model/provider, duration where available | Sidekick usage accounting |
| `error` | stable error code, safe message, redacted diagnostic metadata, terminal flag | Sidekick run terminal/error state |
| `done` | final lifecycle state, usage, terminal result/error summary, last seq | Sidekick run terminal state |

### Reconnect metadata

Every active or terminal run must expose:

- `run_id`
- `session_id`
- current `status`: `queued`, `running`, `awaiting_approval`,
  `awaiting_clarify`, `paused`, `cancelling`, `cancelled`, `failed`,
  `completed`, or `expired`
- last committed event cursor / `last_event_id`
- terminal state and final result/error when finished
- currently available controls
- pending approval/clarify ids, if any
- session-to-active-run mapping for the current WebUI session

### Controls

| WebUI control | Required semantics | Runtime endpoint / IPC |
|---|---|---|
| cancel | Request graceful cancellation of the current run; terminal event must follow | `cancel_run` / `interrupt` |
| queue / continue | Append follow-up work to a live, paused, or resumable run/session according to Sidekick semantics | `queue_or_continue` |
| approval | Resolve a pending approval request with `allow_once`, `allow_session`, `always`, or `deny` where supported | `respond_approval` |
| clarify | Submit answer text or selected choice for a pending clarify request | `respond_clarify` |
| goal | Set/status/pause/resume/clear goal where Sidekick exposes goal capability for this surface | command/capability API |
| observe | Attach to live events and replay from cursor | `observe_run` |
| status | Poll lifecycle state when SSE/WebSocket is unavailable | `get_run` |

WebUI may keep local UI state such as which disclosure rows are expanded, but it
must not infer or privately mutate runtime state for these controls.

## Sidekick Runtime API / IPC v0 minimum

The transport can be HTTP, stdio IPC, websocket, or another Sidekick-owned local
protocol. The key requirement is the semantic contract: Sidekick owns the run id,
lifecycle, event cursor, controls, pending human-interaction state, and terminal
state.

### `start_run`

Creates a Sidekick-owned run.

Input fields:

- `session_id` or instruction to create one
- user message / queued input
- workspace context and attachments metadata
- profile/provider/model/toolset hints
- source/surface metadata, e.g. `source=webui`
- optional command intent, e.g. `/goal` if parsed by WebUI command UI
- idempotency key for duplicate browser submissions

Output fields:

- `run_id`
- `session_id`
- initial `status`
- `observe` cursor / first event id
- supported controls for this run

### `observe_run`

Streams ordered run events, with replay from a cursor.

Required behavior:

- support `after_seq` or `Last-Event-ID`
- emit events in monotonically increasing per-run order
- replay terminal `error` / `done` state for completed runs
- make duplicate delivery safe for reconnecting clients
- preserve enough history for short WebUI restarts and browser reloads

### `get_run`

Returns current lifecycle state without consuming the event stream.

Required fields:

- `run_id`, `session_id`, `status`
- `created_at`, `updated_at`, optional `completed_at`
- `last_seq` / `last_event_id`
- active controls
- pending approval/clarify summaries
- terminal result/error summary
- usage/model/provider/profile/toolset summary where available

### `cancel_run` / interrupt

Requests graceful run cancellation or interruption. Sidekick owns the final state
transition and emits a terminal event. WebUI should not directly toggle a local
cancellation flag as the source of truth.

### `queue_or_continue`

Submits follow-up work for a live, paused, or resumable run/session. Semantics
must match Sidekick-native queue/continue behavior so WebUI does not create a
parallel continuation model.

### `respond_approval`

Resolves a pending approval request by id.

Required behavior:

- validate the approval belongs to the run/session
- accept only supported choices
- emit `approval.resolved`
- continue, pause, or fail the run according to Sidekick approval semantics

### `respond_clarify`

Resolves a pending clarification request by id.

Required behavior:

- validate the clarify request belongs to the run/session
- accept text or selected-choice payloads
- emit `clarify.resolved`
- continue or fail the run according to Sidekick clarify semantics

## Gap matrix

| Current WebUI primitive | Current role | Sidekick-owned target | Temporary shim allowed? | Notes / gap |
|---|---|---|---|---|
| `STREAMS` / `STREAMS_LOCK` | Process-local live stream registry and subscriber fan-out | Sidekick run registry + `observe_run` replay/fan-out | Yes, adapter may keep per-browser SSE connections only | Shim must not be the run source of truth and must survive WebUI restart by re-observing Sidekick. |
| `CANCEL_FLAGS` | Local cancellation signal checked by WebUI-owned agent thread | `cancel_run` / interrupt control | No, except translating button clicks into runtime calls | Cancellation result must come back as Sidekick status/events. |
| `AGENT_INSTANCES` | Cached `AIAgent` objects inside WebUI process | Nova runtime owns agent construction/reuse | No | Keeping this in the adapter would recreate the runtime surrogate. |
| Partial text buffers | Reconstruct live assistant deltas for browser reconnect/render | Sidekick event log/cursor plus WebUI renderer cache | Short-lived presentation cache only | Source should be replayed token events or persisted transcript, not WebUI-only execution state. |
| Reasoning buffers | Preserve streamed reasoning/thinking text | Sidekick reasoning events + replay | Short-lived presentation cache only | Replay must rebuild the same thinking cards after refresh. |
| Tool buffers / live tool calls | Render tool cards and updates | Sidekick tool lifecycle events + replay | Short-lived presentation cache only | WebUI owns card rendering, not tool execution state. |
| Approval callbacks and queues | Bridge WebUI buttons to a live Python callback | Sidekick pending approval state + `respond_approval` | No private callback queue | Pending approval must be discoverable after WebUI restart. |
| Clarify callbacks and queues | Bridge WebUI form to a live Python callback | Sidekick pending clarify state + `respond_clarify` | No private callback queue | Pending clarify must be discoverable after WebUI restart. |
| Command capability metadata | Decide which slash commands render/execute in WebUI | Sidekick command registry/capability API with owner/surface metadata | WebUI may cache metadata | Unknown commands should not be reimplemented in WebUI by default. |
| Session-to-active-run mapping | Stored implicitly in WebUI session JSON / active stream ids | Nova session/run mapping API | WebUI may cache last seen run id | Reopen session must rediscover active/completed run from Sidekick. |
| Reconnect/replay behavior | Depends on WebUI process memory and session JSON | `observe_run(after_seq)` + `get_run` terminal state | Browser SSE adapter only | First milestone must prove WebUI restart does not orphan the run. |
| Usage/title/status events | Produced by WebUI streaming callbacks | Sidekick usage/title/status events and run state | WebUI formatting only | WebUI can display and persist presentation copies after events arrive. |
| Goal / queue / continue hooks | Mixed WebUI command handling and streaming callbacks | Sidekick command/control plane | Only UI affordance shim | Goal support should be driven by Sidekick capabilities. |

## Migration ladder

1. **Inventory and contract**: keep this RFC current with the current WebUI-owned
   runtime primitives and browser event/control contract.
2. **Sidekick Runtime API / IPC v0**: add or stabilize upstream Sidekick primitives
   for `start_run`, `observe_run`, `get_run`, `cancel_run`, and replayable event
   cursors.
3. **Read-only observation spike**: from WebUI, observe an existing Sidekick-owned
   run and adapt its events into WebUI-compatible event objects without starting
   a WebUI-owned agent thread.
4. **Feature-flagged new-run path**: route new WebUI runs to Sidekick-owned
   `start_run` behind a flag while preserving the legacy path as fallback.
5. **Restart/reattach milestone**: prove a non-trivial WebUI-started run
   survives a WebUI-only restart and browser reload with ordered replay.
6. **Controls migration**: move cancel, queue/continue, approval, clarify, and
   goal controls to Sidekick-owned endpoints/capabilities.
7. **Parity tests**: compare legacy and adapter event streams for synthetic
   token, reasoning, tool, approval, clarify, error, and done scenarios.
8. **Retire runtime surrogate state**: remove normal WebUI chat ownership of
   `AIAgent`, cancellation flags, callback queues, and process-local run truth
   once parity and fallback criteria are satisfied.

## First success criterion

The first implementation milestone is not "basic chat streams through a new
endpoint." The first meaningful milestone is:

1. Start a non-trivial chat run from WebUI through the Sidekick-owned path.
2. Restart only `hermes-webui` while the run is active.
3. Reload or reopen the browser session.
4. Rediscover the same `run_id` from Sidekick using `session_id` or last known run
   metadata.
5. Replay events from the last cursor with no duplicate visible transcript
   content.
6. Render the same token/reasoning/tool/approval/clarify state the workbench
   would have rendered without the restart.
7. Cancel the run from WebUI and observe Sidekick emit the terminal cancelled
   state.

If this works, WebUI is moving toward a protocol translator over Sidekick-owned
execution instead of becoming another runtime with different variable names.

## Open questions

- Where should the normative Sidekick Runtime API / IPC v0 spec live: in
  `NousResearch/hermes-agent`, this WebUI RFC, or both with one designated
  source of truth?
- What retention window is enough for v0 event replay: active-run memory only,
  SQLite-backed event log, or transcript-derived reconstruction plus terminal
  state?
- Should WebUI talk to Sidekick over the existing API server, an embedded IPC
  channel, or a profile-local runtime socket?
- How should multiple clients observing the same run coordinate controls and
  pending approval/clarify prompts?
- Which slash commands need surface-specific capability metadata before WebUI
  can safely delegate them to Sidekick?
