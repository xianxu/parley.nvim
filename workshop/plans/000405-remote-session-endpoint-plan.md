---
collaboration-mode: discussion
---

# Private editor endpoints implementation plan

> **For agentic workers:** Follow AGENTS.md Section 3. Bounded independent work may use subagents; SDLC owns each mandatory review. Checkboxes track execution.

**Goal:** Plain Neovim opens advertise private RPC endpoints for registered session files and side docs to Couch, with safe supersession and teardown.

**Architecture:** Couch owns endpoint authority and process identity; Parley owns each listener and one pure attachment lifecycle. Existing confirmed document admission supplies identities in Couch panes; outside panes, one read-only lookup discovers membership without changing submit behavior. Pair#758 M1 is the producer prerequisite; pin its durable contract before code, and consume its landed main rather than stacking branches.

**Tech stack:** Lua, Neovim 0.11/0.12 serverstart/serverstop and libuv, bounded Couch CLI JSON, existing executable fake and embedded-Neovim helper.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| EndpointAttachment | lua/parley/remote_session_model.lua | new |

EndpointAttachment owns one live buffer attachment's namespace/document ID, process incarnation, monotone AttachID, request witnesses, binding generation and phase. Its only mutation surface is dispatch(event); snapshot() returns copies. It validates endpoint envelopes and notification tuples without editor/process IO. Multiple endpoints belong to one nvim incarnation; a fresh explicit attach advances the process-wide decimal counter. Retry preserves AttachID. Counter exhaustion refuses remote publication rather than wrapping. This is the first occurrence of this ownership pattern; reuse the existing document-registration and request seams rather than embedding it in operator_admission (ARCH-PURE/DRY/ORDER).

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| Editor endpoint shell | lua/parley/remote_session.lua | new | private directory/listeners, native callbacks, lifecycle events |
| Endpoint CLI transport | lua/parley/document_registry.lua | modified | existing bounded Couch process queue, stdin JSON and typed replies |
| Registered identity handoff | lua/parley/session_sync.lua | modified | attach/identity-upgrade, move pause/confirmation, detach |
| Markdown/exit wiring | lua/parley/init.lua | modified | outside-pane open discovery and VimLeavePre |
| Stateful endpoint fake | tests/fixtures/fake_couch_registry.py; tests/helpers/fake_couch.lua | modified | persisted endpoint authority and controlled reply order |
| Real conformance | scripts/check-couch-registry-conformance.py | modified | isolated Pair producer and real Neovim socket |

No remote web API, tunnel, arbitrary remote operation dispatcher, headless spawning or phone UI is implemented here. Pair#758 owns proxy allowlisting and checking current binding on established connections; stopping a listener cannot revoke an already-open RPC channel.

## Producer contract (jointly pinned with pair:6; durable M1 pin pending)

- CLI: couch --editor-endpoint register --json and unregister --json consume bounded version-1 JSON from stdin. Read-only lookup takes --namespace CANONICAL --document-id ID --json.
- Existing document lookup/register replies add Registration.Namespace. Only confirmed registered identity starts a listener; null, malformed, unsupported or unavailable discovery never registers a document or creates a listener.
- Register carries Namespace, DocumentID, EditorIncarnation (32 lowercase hex, random once per process), AttachID (canonical positive decimal counter), PID, Socket, Buffer and Mode desktop|headless. The nvim frontend uses desktop; headless policy is producer-owned.
- Couch derives ProcessIdentity, an opaque native start-identity string. A confirmed EditorEndpoint envelope echoes the complete tuple plus canonical File and BindingGeneration. Namespace + DocumentID is authoritative, not a path supplied by a client. Stable ID survives rename.
- Same complete attach retry preserves its generation; a retired/superseded AttachID cannot reclaim. New explicit desktop attach wins; headless cannot displace a live desktop. Unregister compares the exact incarnation/AttachID/generation and cannot erase a successor.
- Unregister batches up to 256 exact rows for one incarnation/PID, reporting removed/stale/absent per row. It must not RPC back into the exiting editor, whose event loop waits for this operation.
- Bounds: register input 8 KiB, batch input 256 KiB/256 entries, reply 1 MiB; whole producer CLI 3 seconds, native identity/notification work 1 second, joined. Codes: 0 success, 2 invalid, 3 unavailable, 4 superseded/conflict/stale, 5 uncertain. Unknown/malformed codes are unconfirmed, never proof of absence.
- Producer cap: 256 active endpoints per editor, 4096 retained editor/document pairs per namespace. Exact dead-process or confirmed retired-attachment cleanup belongs to Couch; failed inspection is unknown. Couch never removes editor directories or guesses ownership of socket paths.
- Before publication, producer brackets a read-only native endpoint handshake with native process identity checks. The fixed code is return require("parley.remote_session").endpoint(...), args=[query]. Query contains Namespace, DocumentID, EditorIncarnation, AttachID, Buffer. Matching pending/current live attachment returns these fields plus PID, Socket and canonical current File; otherwise nil.
- Displacement uses a bounded one-shot callback outside the registry lock: return require("parley.remote_session").superseded(...), args=[notice]. Notice contains exact Namespace, DocumentID, EditorIncarnation, AttachID, BindingGeneration. This is advisory; server-side authority remains current binding generation.
- The final durable producer artifact, exact JSON shape and empty/unknown outcomes must be cross-checked before change-code. Do not infer a working producer from a fake.

## Lifecycle and visible behavior

Actions: open/reopen a file; continue editing locally; close the buffer/editor.

| Internal state / failure mode | Visible state | Recovery action | Possible loss |
|---|---|---|---|
| plain / unknown membership | ordinary local editor | continue editing locally | remote view unavailable; no document loss |
| discovering or publishing | ordinary local editor; remote connection pending | continue editing locally | no remote availability claim before ack |
| active current binding | ordinary local editor; remote view available | continue editing locally | none from endpoint bookkeeping |
| failed/unconfirmed discovery or publication | notice: remote view unavailable; reopen to retry | reopen file | endpoint outcome may be unknown; local edits preserved |
| superseded | notice: remote view moved to another editor; reopen to take it back | reopen file | this editor no longer serves the remote view; local edits unchanged |
| detached/exit with cleanup pending | buffer/editor closes normally | close | stale row may remain until exact producer cleanup; no local content or lock release |

The new lifecycle never changes modifiable, admission history, lock ownership, saves, submit composition or existing refusal bands. Notices are bounded and deduplicated, separate from the operator-lock renderer. No automatic takeover/re-register loop.

### Transition contract

- open -> discovering; one read-only lookup per explicit outside-pane Markdown attachment. In-pane admission reuses its confirmed registration, including later legacy-to-registered identity upgrade; no duplicate discovery.
- registered -> create a fresh pending attachment and private listener -> publishing. Store pending tuple before the asynchronous CLI begins so endpoint(query) can answer its handshake.
- publishing + matching confirmed ack -> active; late replies belonging to another attachment are ignored for activation and may trigger only exact-owned cleanup.
- publishing + timeout/invalid/uncertain outcome -> unconfirmed, preserving incarnation/AttachID and any known generation. Reopen is a new explicit attach; no retry with a new identity disguised as the old operation.
- active + exact supersession -> superseded, notify once and stop only that attachment's listener. Stale/malformed notices have no effect.
- publishing + matching notice before ack -> retain one provisional notice generation. When ack arrives, compare generations before activation; a notice for that exact binding makes the result superseded. Never treat an unknown generation as confirmed ownership.
- move admission pauses publication/listening for that buffer. Once existing move finalization confirms the same document ID and new canonical File, publish a fresh attachment. A pre-effect abort resumes only proven old identity; interrupted moves remain unavailable remotely. Native buffer-name validation also makes the endpoint handshake return nil for a stale spelling.
- detach/wipe -> retire pending/active attachment, cancel unstarted work, exact-unregister known bindings, stop owned listeners. A registration that completed after detach is cleaned using its returned exact witness; it never activates a dead buffer.
- exit -> one batch of known owned bindings, 500 ms total client budget, then stop only owned listeners and permit exit. Unknown cleanup remains producer-owned; never extend shutdown per buffer or retry in a loop.
- Process death is a producer cleanup boundary. Failed native inspection/socket connection is not absence. A matching endpoint(query)=nil while listener is still reachable is positive retired-attachment evidence; unreachable live-process residue can stay bounded until explicit reopen or confirmed process death.

## Socket ownership and operating envelope

- One process-owned directory, created with mkdtemp below Neovim's private runtime directory, mode 0700, physical directory owned by current uid. Verify lstat/type/uid/permissions; never chmod or reuse a foreign/symlinked directory.
- One listener per registered live attachment (at most 256), short serial socket names inside that directory. Check platform Unix socket length before serverstart; an overlong path or failed private allocation degrades only remote availability, never chooses a public directory or TCP port.
- Keep every pre-existing Neovim server intact. Only listeners returned by this module's serverstart are stopped. Teardown unlinks/rmdirs only exact owned artifacts; no recursive glob/delete.
- Normal open/publication is async through the existing bounded registry queue (4 active/64 queued). Request lifetime is 3 seconds; overload is a visible unavailable outcome. No subprocess, scan or new timer per keypress.
- With N opens and N attached buffers, discovery/publication is O(N) total, callbacks O(1) keyed by buffer/attach; exit is one batch plus O(N) local listener cleanup. Count requests/listeners at 8 and 16 attachments; reject repeated open events causing extra registration. Memory is O(N), max256.
- Runtime artifacts are needed only while a listener serves an attachment. Graceful close stops/removes exact owned sockets; last close removes the empty owned directory. On process death, Neovim runtime cleanup plus Couch's stale binding cleanup are the existing owners; validate crash residue behavior in M1 and pin a bounded owner before claiming completion (ARCH-FUNERAL).

## Architecture checks

| Principle | Applied decision |
|---|---|
| ARCH-DRY | Couch alone owns endpoint authority; existing admission and bounded transport reused |
| ARCH-PURE | sole pure attachment owner; IO shell executes effects and returns witnessed outcomes |
| ARCH-PURPOSE | parent and side docs, outside-pane plain opens, supersession and teardown all included |
| ARCH-MOCK | persisted endpoint fake shares production CLI seam; real producer/socket conformance required |
| ARCH-CONSTRAINTS | async open, fixed queue/cap, reply/input bounds, one bounded exit batch, counted N/2N |
| ARCH-SECURE | Unix-only private runtime boundary, typed ack/notice validation; no network exposure or document registration from discovery |
| ARCH-ORDER | explicit notice-before-ack, detach-before-ack, move, supersession and uncertain teardown rows |
| ARCH-FUNERAL | owned listener/directory cleanup and producer row cleanup, crash residue check named above |
| ARCH-EVOLVE | additive Registration.Namespace copied through existing registration model; producer owns separate endpoint persistence and mixed-version rules |

## Implementation and verification

### M1 — endpoint model, private listener shell and producer conformance

**Files:** new lua/parley/remote_session_model.lua, lua/parley/remote_session.lua; modify lua/parley/document_registry.lua, tests/fixtures/fake_couch_registry.py, tests/helpers/fake_couch.lua, scripts/check-couch-registry-conformance.py; new tests/unit/remote_session_model_spec.lua, tests/integration/remote_session_spec.lua; update atlas and traceability.

| Function / boundary | Verification strategy |
|---|---|
| model.new/dispatch/snapshot | IO-free sequence tests; assert exact incarnation/generation ownership, copied state, ignored stale replies, notice-before-ack and detach-before-ack |
| model.classify_reply | strict type/identity/namespace/path/code validation; truncated/missing/old replies remain unknown, extra harmless fields tolerated |
| remote_session endpoint(query)/superseded(notice) | native RPC against real listeners; exact pending/current query echoes, malformed/stale notice ignored, exact displaced binding retires once |
| listener allocation/stop | actual socket connect, 0700 uid-owned directory, symlink/foreign/length negatives; other Neovim servers survive cleanup |
| endpoint CLI request | stateful executable fake covers current/superseded/retired and ordered delayed replies; byte/deadline/cancel bounds through production seam |
| real conformance | isolated producer main pin plus real Neovim: registration, same-attach retry, second-editor takeover, stale unregister, lost ack and retired attachment cleanup |

- [ ] Record the landed producer contract pin and settle runtime crash-residue ownership; do not begin implementation on an unpinned contract.
- [ ] Add failing pure sequences, then the minimal sole owner; run unit specs red/green.
- [ ] Add failing socket/CLI tests through the stateful fake, implement thin shell/transport, then run targeted integration red/green on 0.12.5 and0.11.7.
- [ ] Extend real conformance with an intentional corrupt-fake negative control; run against producer merge pin in isolated roots.
- [ ] Update indexed atlas/traceability; commit; recorded suite and milestone-close M1 through SDLC.

### M2 — real attachment lifecycle and desktop acceptance

**Files:** lua/parley/session_sync.lua, lua/parley/init.lua, lua/parley/remote_session.lua; tests/integration/session_sync_native_spec.lua, new tests/integration/remote_session_native_spec.lua, tests/integration/zero_config_spec.lua; README and atlas/modes/session_sync.md plus new indexed atlas/modes/remote_session.md.

| Function / boundary | Verification strategy |
|---|---|
| attach/identity-upgrade | confirmed registered parent/side doc advertises once; legacy-only header, null/unknown membership and ordinary Markdown do not create listeners |
| outside-pane open | actual nvim with Couch pane env absent; one read-only lookup, plain nvim filename needs no flag, outside-pane Alt+Return behavior unchanged |
| move pause/finalization | native rename/saveas recovery retains document ID, never advertises old spelling; no endpoint publication from interrupted journal |
| detach/wipe/exit | buffer wipe removes only owned generation; two native editors prove old wipe/exit cannot remove successor; one bounded exit batch and clean process census |
| scaling/control | counted 8/16 attachments; duplicate attach events, reloads, saves, insert and status callbacks do not create extra registration requests/listeners |

- [ ] Add native red cases before lifecycle wiring; connect existing confirmed identity and move boundaries without changing operator_admission.
- [ ] Test every teardown and supersession ordering on both supported runtimes; verify plain-file and outside-pane submit controls.
- [ ] Run focused mapping, lint, fake and real conformance; push final head and queue the recorded suite.
- [ ] Request a brief fixture-only real-profile stage from TL once producer is deployed and suite green; check parent/side doc, takeover and cleanup; clear immediately and verify :0 against fresh main.
- [ ] Close/review through SDLC, fix findings, run any required fresh evidence, then sdlc merge --yes; report verified PR/merge to hub.

## Planning status

TL approved producer-before-consumer order and one outside-pane discovery lookup (2026-10-22). Pair:6 owns pair#758 M1 and has agreed the contract sketch above. Await its durable contract/merge pin and TL approval of this plan; no implementation has begun, and no estimate is derived before change-code accepts the plan.
