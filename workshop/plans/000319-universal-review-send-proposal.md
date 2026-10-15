# Universal review submissions implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Send a few lines plus real changes for document review, with one ariadne-owned review protocol and a working standalone fallback.

**Architecture:** Ariadne owns the round, six existing stock modes and canonical marker grammar. Parley ships generated snapshots for fallback/local review. After S1 lands, compose the review payload inside its existing registered-submission flow; retain S1 as the only owner of admission, transport, receipt reconciliation and retries.

**Tech Stack:** Lua/Neovim, Python standard library for deterministic snapshot generation, ariadne skill export, existing Couch transport and stateful fake.

**State:** Proposed to the hub; do not run change-code until approved. Full flow is expected because canonical-source distribution and the S1 integration exceed a small message-only patch. One atomic Parley close, no milestone tags.

## Dependencies and decisions

- Shared half: **ariadne#399**, filed unclaimed for hub dispatch, depends on S1 (**parley.nvim#332**, **pair#573**). It must land first. Parley consumes the export; this slot does not implement ariadne's skill.
- Read ops `teams/devinfra/projects/universal-agent-input-interface/design.md` S2 and `project.md` S2a. S2a lifts today's review modes; section-level collaborate/chat modes, side-doc lifecycle and new edit presentations remain their later project slices.
- #332 owner confirmed its parked PR #241 routes every named Markdown Couch submit through `agentic_document.submit` -> `session_sync.prepare_submit` -> `session_sync.send_registered`. An explicit process-instruction does not bypass admission. Its final dedup/receipt work is still pending. Wait for that landing and confirm the final seam before implementation; never build on its unlanded branch.
- **Approval needed:** extend the registered-send payload seam for explicit review instructions. Preserve S1's simple submitted message for files without an instruction and legacy session files. No second send, watcher, owner resolver or retry loop.

Alternatives considered:

1. **Recommended:** a payload adapter within S1, plus generated canonical fallback. It serves the operator's actual Couch path and preserves S1 state ownership.
2. Change only review_send.message. Smaller, but S1 bypasses it in Couch, so this would miss the motivating behavior.
3. Keep S1's submitted-only body everywhere and have the skill read the instruction/diff from disk. Simpler transport, but changes the operator's revised payload contract and does not preserve the existing last-send diff. Requires a different explicit scope decision.

## Core concepts

### Pure entities

| Name | Lives in | Status | Responsibility |
| --- | --- | --- | --- |
| `ReviewMessage` | `lua/parley/review_message.lua` | new | Build short or inline bodies from validated protocol data, raw instruction and optional real diff. |
| `instruction.parse/resolve/expand/brief` | `lua/parley/skills/review/instruction.lua` | modified | Reuse existing mode selection and render generated canonical mode data; no second mode resolver. |
| `ReviewBundle` | `lua/parley/review_protocol.lua` | new | Validate versioned bundle metadata and select shared versus inline use from explicit capability evidence. |

ReviewMessage receives values, never reads files or sends. Existing review_send.message remains a delegating compatibility entry point. ReviewBundle has one supported schema/version, fixed member names and validated dense mode records; malformed or missing installed data selects the packaged inline bundle. Both entities have direct unit tests without IO mocks.

### Integration points

| Name | Lives in | Status | Wraps |
| --- | --- | --- | --- | --- |
| `ReviewProtocolLoader` | `lua/parley/review_protocol_io.lua` | new | Read bounded packaged/installed skill files and canonical paths. |
| `ReviewSubmissionAdapter` | `lua/parley/review_send.lua` | modified | Save/content snapshot, existing baseline and pure message construction. |
| `RegisteredSubmission` | `lua/parley/session_sync.lua`, `lua/parley/agentic_document.lua` (after #332) | modified | S1's single send, registration/identity, lock reconciliation and receipt callbacks. |
| `ReviewSource` | `lua/parley/skills/review/init.lua` | modified | Compose generated round/grammar plus the local propose_edits adapter. |
| `ReviewExportGenerator` | `scripts/sync-review-protocol.py` | new | Deterministic canonical inputs -> packaged protocol, modes and provenance manifest. |
| `FakeCouch` | `tests/helpers/fake_couch.lua` and #332's registry fake | modified | Persist actor/registry state, message attempts and controlled receipt outcomes. |

## Canonical source and fallback contract

Ariadne #399 supplies `construct/local/universal-review/SKILL.md`, `round.md`, the six current `modes/*.md`, and a versioned export manifest naming these and `construct/local/fix/review-convention.md`. Its file-edit adapter owns Couch read/diff/write, lock and owed-fold instructions; its skill references the canonical grammar rather than restating it. Confirm the exact export names with that owner before generation.

Parley generates `lua/parley/skills/review/round.md`, `review-convention.md`, the existing six `modes/*.md`, and `protocol.json` from that export. These are release snapshots with provenance and hashes, not independently authored rules. Keep one Parley-specific `local-adapter.md` for propose_edits invocation; generated SKILL.md composes shared round/grammar with that adapter. The inline file-edit fallback embeds the generated round, selected mode brief and ariadne file adapter, and names the absolute packaged grammar path for the agent to read. The grammar itself is already 8,774 bytes, larger than Couch's entire 8,192-byte message limit; do not paste the full grammar into a send. Local review prompts can compose the full generated grammar because they do not use the Couch message envelope. No consumer keeps a hand-maintained protocol or mode body (ARCH-DRY, ARCH-PURPOSE).

The generator has explicit `--source DIR`, `--output DIR`, and `--check` modes; it uses real temporary fixture directories in tests. `--check` exits nonzero for changed, missing or extra generated members. Releases retain the committed bundle and need no sibling ariadne or weave at runtime. Integration tests always check packaged hashes/member integrity, and compare against the pinned source when it is installed; standalone fixtures explicitly lack that source and still exercise the fallback. Run generator --check before close. Do not edit protected local-gate configuration in this issue.

Capability is evidence about the receiving slot, not the document's repository or agent brand. On the pane's own verified actor, COUCH_TREE names its checkout. Probe that checkout's supported harness skill directories for a readable xx-universal-review skill and a compatible export version. Include its absolute skill path in the short use-skill line, so an already-running agent can read it even if its discovery menu predates installation. Do not derive a worktree from Binding.Repository: it is the shared Git directory. For another owner, missing root, missing skill, stale version or unreadable files, select inline fallback. Never suppress the send merely because optional shared-skill evidence is absent.

## Payload and S1 seam

For a compatible skill, no real diff:

```text
review request: /absolute/document.md
process-instruction: [copy-edit] keep the voice
Respond by editing the file in place (review convention: 🤖 markers).
Use the xx-universal-review skill at /absolute/skill/SKILL.md.
```

No Review mode/How to apply/operator-instruction repetition, first-send banner, empty Changes heading or No change paragraph. A nonempty actual diff appends one concise last-delivered-send heading and a fenced diff; preserve the 200-line cap and explicit truncation notice. Do not send a diff against a failed/unconfirmed attempt.

For an incompatible/unknown skill, append the generated file-edit protocol and existing expanded mode brief, plus the absolute packaged grammar path, then the same real diff. The mode prefix aliases, multiple modes and first-mode flags remain as today. Outside Couch, preserve the in-editor invocation path and its tool adapter. Session-file turn handling and S1's no-instruction submitted message remain unchanged.

Proposed seam after #332 lands:

- RegisteredSubmission captures a candidate only after save/registration/identity reconciliation, then calls the review adapter once with `{path, registration, own_actor, lines, submission_generation}` when an explicit process-instruction denotes a review round.
- The adapter returns `{body, on_submitted}`. It uses the current successful-send baseline, validated bundle/capability and pure message builder. It does not call Couch or register a file.
- S1 sends that frozen body through its existing send_registered path and owns retry/dedup/receipt handling. A retry of the same attempt uses the same body/identity; a fresh operator submission gets a fresh candidate. No payload builder runs again during receipt polling.
- Only S1's confirmed submitted outcome invokes on_submitted with the captured content. Queued/unconfirmed, failed, cancelled, stale identity and superseded completions do not advance the baseline. Use #332's final tagged result/witness types, not a new parallel receipt machine. If its final interface cannot express this, stop and revise the plan with the hub.
- Preserve the legacy review-send path for environments S1 does not admit, delegating its formatting to ReviewMessage and retaining its existing save/error behavior.

The pure builder exposes a typed-result convention rather than substituting an
empty string for an invalid round:

```lua
-- ReviewMessage.build({path, instruction, protocol, shared_skill_path, diff})
-- -> {kind="ready", body=...} | {kind="refused", reason=...}
-- protocol contains validated generated round/file-adapter/mode values.
-- A nil shared_skill_path selects inline fallback. nil/empty diff adds nothing.
-- Reserve the complete base before fitting a real diff into remaining bytes.
-- On refused, the IO caller notifies and leaves the successful baseline alone.
```

## Architecture constraints and lifecycle

- **ARCH-PURE/DRY:** pure message/bundle values; filesystem loading and S1 transport in explicit seams. Keep the existing mode resolver and Couch fake.
- **ARCH-PURPOSE:** cover the actual registered Couch path, inline fallback and local review adapter; generated snapshots enforce the one-source claim.
- **ARCH-MOCK:** extend the stateful Couch fake with the final S1 receipt contract, captured exact bodies and persisted attempts. Test success, failed/unconfirmed send, explicit retry, stale callback and registration/owner changes. A live staged check against the real Couch pane confirms the fake's consumed contract before landing.
- **ARCH-CONSTRAINTS:** submit-time work, never typing/startup polling. No new process on the normal path; at most 256 KiB total protocol data per load and at most six stock modes (current requirement). File reads are bounded; invalid/oversized installed data selects packaged inline fallback. Keep the 200-line diff cap and enforce Couch's 8,192 UTF-8-byte envelope: calculate remaining bytes after the complete round, trim only the diff at a UTF-8 boundary with an explicit notice, and visibly refuse an oversized instruction/base body without sending or advancing the baseline. Require the generated fallback base to fit below 6 KiB for ordinary paths/instructions; test that budget with the actual generated bundle. Test representative first/repeated sends and large diffs; do not claim new latency guarantees without measuring them.
- **ARCH-SECURE:** document/frontmatter text is data in argv arrays; no shell interpolation. Validate bundle schema/version, member paths and sizes at load. Only fixed protocol members are opened; broken symlinks, truncated JSON, unknown versions or hashes are incompatible rather than proof of capability. No credentials are created or read.
- **ARCH-ORDER:** S1 remains authoritative for the stateful submission. The callback witness binds canonical file, registration/owner, content snapshot and generation; an unconfirmed receipt is not success. Sequence tests control callback order and prove late/duplicate completions cannot change the selected baseline. No detached background work or timer is added by this feature.
- **ARCH-FUNERAL:** no new runtime files, cache, receipt journal or watcher. The existing baseline map dies with the editor. Bundled export files are fixed-size release artifacts replaced by generation; temporary test roots are removed by fixture teardown. S1 owns its existing durable attempt cleanup.

## Execution tasks

### 1. Confirm foundation and source export

- [ ] Obtain hub approval for this plan and the explicit S1 payload extension; ariadne #399 is dispatched by the hub.
- [ ] Wait for #332, pair#573 and #399 to land. Refresh from main through SDLC; do not stack on a parked issue branch.
- [ ] Confirm #332's final callback/witness and dedup semantics with its owner. Record any interface delta in Revisions, then run `sdlc change-code --issue 319 --flow full` for plan-quality and the derived estimate before code.

### 2. Generate one protocol bundle

Files: create scripts/sync-review-protocol.py, protocol.json, round.md, review-convention.md and local-adapter.md; regenerate existing modes and SKILL.md. Tests: tests/integration/review_protocol_bundle_spec.lua.

- [ ] Write fixture-based generator tests: valid six-mode export, deterministic output, stale snapshot, missing member, invalid manifest and standalone load without ariadne. Run the targeted mapped review suite and record failures.
- [ ] Implement exact-member export and --check. Add provenance rather than authored copies; run the tests green and commit the canonical-source consumer.
- [ ] Confirm copy-editing/developmental/fact-check/free-form/line-editing/proofreading names, flags and bodies match the source byte-for-byte. Do not invent generate or section modes.

### 3. Build pure message and capability decisions

Files: create lua/parley/review_message.lua, review_protocol.lua, review_protocol_io.lua; modify review_send.lua and local source composition. Tests: tests/unit/review_message_spec.lua, tests/unit/review_protocol_spec.lua, tests/integration/review_protocol_bundle_spec.lua; retain tests/unit/review_instruction_spec.lua.

- [ ] Write exact-output unit tests for short first/unchanged sends, real/truncated diff, the 8,192-byte boundary (including multibyte text and one huge diff line), oversized-base refusal, all existing modes and unique prefixes, inline fallback and raw instruction quoting. Test capability available/missing/stale/malformed/remote-owner choices as values.
- [ ] Run targeted tests red. Implement deterministic message construction and bounded loader, without new transport or mode semantics. Run green and commit.
- [ ] Verify a packaged plugin with no ariadne checkout still runs the local review and produces a complete inline round; generated grammar uses the canonical single-line marker/<br> contract.

### 4. Connect the actual registered submission

Files: modify review_send.lua and #332's landed session_sync.lua/agentic_document.lua seam only. Tests: tests/integration/review_send_spec.lua, #332's agentic-document/registry receipt specs and the existing fake.

- [ ] Add regressions that press the real Alt+Return keymap: an explicit instruction reaches the registered payload builder; absent instruction keeps submitted-only; actual chat/visual/session routes preserve their owners.
- [ ] Test own-slot compatible skill -> four lines, unavailable skill -> complete inline round, explicit other owner -> conservative fallback. Ensure no registration/owner/admission check is bypassed and only one message is sent.
- [ ] Add controlled outcome sequences: accepted/submitted -> edit -> real diff; failed -> retry against prior success; unconfirmed -> later receipt; duplicate/late/superseded callback; rename/registration change while outstanding. Confirm S1 alone owns dedup/resend and that the baseline changes only on confirmed current submission.
- [ ] Run red, implement the agreed adapter seam, run green and commit. Reuse S1's final state transition; no second watcher, receipt journal or retry loop.

### 5. Verify, stage, review and land

Files: README.md, atlas/modes/review.md, atlas/traceability.yaml, issue Log/plan. The hub owns the ops project file.

- [ ] Update documentation and traceability for the short message, fallback detection and shared source; document that mode semantics come from the ariadne export.
- [ ] Run `make test-spec SPEC=modes/review`, `make check-vocabulary`, the new snapshot --check command, and `git diff --check`. Record red/green and conformance evidence.
- [ ] Push through `sdlc pr`, run `sdlc local-check run --name suite` to record the full suite once, and retain the exact-head log/status.
- [ ] Per tl-worker, stage with `sdlc stage --build`; ask the hub for the real-pane check: submit a file with instruction, inspect the short delivery, edit/resubmit and inspect the diff, then simulate unavailable shared skill in an isolated fixture for fallback. Do not change the operator's environment directly.
- [ ] Run `sdlc close --issue 319 --verified '<concrete evidence>'`, address the binary's mandatory review, and land on SHIP using `sdlc merge --yes` with green checks. Clear a leftover stage if landing does not; report the PR/outcome to the hub.

## Revisions

- 2026-10-15 — initial S2a proposal. #332 owner confirmed all named Markdown in Couch bypasses the old message builder; this plan therefore requests a payload extension inside S1 instead of changing an unreachable path. Shared half filed as ariadne#399. No implementation authorized until the hub approves this integration choice.
