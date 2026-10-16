# Universal review submissions implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every Couch document submission carries only `submitted: PATH`; the shared skill owns instruction reading and change computation, while outside-Couch review retains its inline prompt.

**Architecture:** Reuse S1's registered submission unchanged. Delete Parley's old Couch review message builder, diff computation and successful-send baseline. Ariadne #399 reads the submitted file's process-instruction and obtains changes since its last read through Couch; Parley's local review source consumes the canonical round/mode data for its existing in-editor fallback.

**Tech Stack:** Lua/Neovim, ariadne's shared skill/export, S1's existing Couch transport and stateful fake. No new transport, payload adapter, runtime capability probe or receipt machine.

**State:** Approved by ops:0 with the submitted-only revision, delivery 9111a425-a6cd-4098-9138-009139f4155c. Implementation waits for ariadne#399 and parley.nvim#332 (whose S1 dependency is pair#573) to land. Do not stack on their unlanded branches. Let change-code infer the flow from the final consumer patch; no milestone tags or estimate before its gate.

## Approved payload and ownership

```text
submitted: /absolute/document.md
```

This is the entire Couch message, including for files with process-instruction. There is no mode brief, skill hint, inline fallback, diff, first-send notice or custom payload on this path. S1's send_registered remains the sole sender and owns registration, canonical identity/owner checks, save/reconcile, operator locks, deduplication, resend and receipt reconciliation.

Ariadne #399 supplies the skill that handles a submission: read the file's frontmatter process-instruction, resolve the existing review modes, and compute **changes since the agent's last read** with `couch --session-sync diff`. This replaces the previous last-editor-send baseline; it deliberately does not promise the old baseline semantics. The skill respects the existing operator lock, CAS write and owed-fold contracts. Section modes extend that skill in the later project slice.

Outside Couch, Alt+Return continues the in-editor inline review via run_via_invoke, including the existing instruction prompt, stock mode selection/completion and propose_edits adapter. This fallback does not send to another agent and does not require an installed shared skill. Missing skill discovery never selects a second Couch payload format: skill rollout is the #399 prerequisite.

## Core concepts

### Pure entities

| Name | Lives in | Status | Responsibility |
| --- | --- | --- | --- |
| `message` | `lua/parley/review_send.lua` | deleted | Old verbose Couch review payload; no replacement builder. |
| `diff` | `lua/parley/review_send.lua` | deleted | Editor-computed changes since last send; the agent reads Couch diff instead. |
| `instruction.parse/resolve/expand/brief` | `lua/parley/skills/review/instruction.lua` | modified | Retain the existing local-review mode semantics using #399's canonical source data. |

No ReviewMessage, capability decision model or new bundle-schema model is introduced. Retain the established pure mode helpers and direct unit coverage. The canonical-source consumer shape follows #399's landed export; do not build a speculative distribution framework.

### Integration points

| Name | Lives in | Status | Wraps |
| --- | --- | --- | --- | --- |
| `review_send.submit` | `lua/parley/review_send.lua` | modified | S1 admission first, otherwise the existing inline in-editor review. |
| `send_to_slot` and `baseline` | `lua/parley/review_send.lua` | deleted | Retired legacy Couch review transport and editor-send state. |
| `ReviewSource` | `lua/parley/skills/review/init.lua` and packaged round/modes | modified | Existing local prompt/tool adapter consumes the shared canonical review data. |
| `RegisteredSubmission` | `lua/parley/agentic_document.lua`, `lua/parley/session_sync.lua` after #332 | reused | S1's unchanged submitted-only transport and receipt ownership. |
| `FakeCouch` | `tests/helpers/fake_couch.lua` and #332's registry fake | reused | Persist registration/attempt/receipt state and capture the exact submitted payload. |

## Canonical source and standalone fallback

Wait for #399's final export contract before choosing filenames or adding generation code. Consume its round, the six existing stock modes and canonical marker grammar for Parley's local inline prompt. Preserve the local propose_edits transport adapter separately from generic round semantics. Release snapshots, if the export uses them, must be generated from that source and checked for freshness/integrity; no manually maintained second protocol or mode body.

A packaged plugin without a sibling ariadne checkout must retain a working local inline review. Reuse the existing source composition and mode resolver rather than creating new runtime loaders or probing the recipient's filesystem. The inline prompt is outside Couch, so no Couch message byte-budget/truncation system is required. The Couch send includes only a path; its existing transport limits/error behavior remain S1-owned.

## Scope and architecture

- **ARCH-DRY/PURPOSE:** one submission payload and one S1 send path. The agent owns file instructions and diff interpretation. Remove both obsolete producers and their state, rather than leaving a dormant alternate sender. Shared-source consumption includes the standalone local review that still needs the rules.
- **ARCH-PURE:** retain mode/instruction transformations as pure helpers; local source composition and S1 admission remain the thin integration boundaries. No new parser for process-instruction in Couch submission code.
- **ARCH-MOCK:** reuse the stateful Couch/registry fake to exercise the real Alt+Return entry point and capture attempts. Preserve S1's receipt tests; verify explicit instructions and missing instructions use the same payload. A staged live check confirms the fake's consumed submission contract.
- **ARCH-CONSTRAINTS:** remove editor diff work and protocol loading from Couch submission. No new subprocess, watcher or capability probe. Outside-Couch prompt construction follows the existing inline path; test packaged startup with no ariadne source installed. No new latency or memory budget is claimed.
- **ARCH-SECURE:** no shell interpolation; paths travel through the existing argv seam and canonical registration checks. Shared exports are validated by their landed contract, and a broken packaged local prompt must fail visibly. No credentials are read or created.
- **ARCH-ORDER:** S1 keeps all stateful admission/send/receipt transitions. This change removes the separate editor-success baseline and adds no new callbacks or authoritative submission state. Regressions prove repeated/failed/retried submits stay inside S1, without falling through to the retired sender. The agent's read/diff/write ordering is #399's responsibility.
- **ARCH-FUNERAL:** delete the per-file baseline map and legacy sender; no new runtime files, timers or cache. Any fixed release snapshot is replaced by the existing/export generation process; temporary test roots are removed by fixture teardown.

## Execution tasks

### 1. Wait for the foundations

- [x] Record hub approval and the submitted-only contract; notify the #399 and #332 owners of this decision.
- [ ] Wait for ariadne#399 and parley.nvim#332 to land; pair#573 remains the S1 prerequisite. Refresh through SDLC and inspect their final contracts before implementation.
- [ ] Record concrete export paths from #399 and the final #332 entry point in the Log. Run `sdlc change-code --issue 319`; satisfy its inferred-flow plan-quality/estimate gates if applicable before editing code.

### 2. Pin the one submission path with failing tests

Files: tests/integration/review_send_spec.lua, #332's landed agentic-document submission tests and existing stateful fake; retain tests/unit/review_instruction_spec.lua.

- [ ] Add keymap regressions for a named Markdown file with an explicit process-instruction and without one. Both must reach S1 and send exactly submitted: ABS_PATH, with one attempt and no protocol, mode hint or diff appended.
- [ ] Test edit/resubmit, failed/uncertain receipt then explicit retry, and unavailable registration through S1's existing fake/control seam. Assert no fallback to a legacy sender or inline prompt while Couch admission owns the request.
- [ ] Add outside-Couch regressions for explicit instruction, prompt-on-missing instruction, cancelled prompt and existing mode aliases. They must invoke the local review with its inline source, with no Couch send and no dependency on skill discovery.
- [ ] Remove obsolete assertions that expect verbose Couch message bodies or an editor-side successful-send diff; retain unrelated pure instruction/frontmatter tests. Run mapped tests red and record the failures before deleting code.

### 3. Delete the retired producer and preserve inline review

Files: lua/parley/review_send.lua, lua/parley/skills/review/init.lua, instruction.lua, existing SKILL.md/modes and the landed #399 export consumer as required.

- [ ] Delete message, diff, DIFF_MAX_LINES, baseline and send_to_slot, and remove the now-unreachable legacy actor-query/send branch and stale module comments. Keep only imports used by the surviving paths.
- [ ] Preserve S1-first admission and the outside-Couch inline review route. Do not modify send_registered's payload or add a callback/adapter to it.
- [ ] Consume #399's canonical round/modes for the local prompt using its landed export mechanism. Keep the existing propose_edits adapter and completion/quoting behavior; verify all six stock modes and first-mode flags.
- [ ] Add standalone fixture coverage with no ariadne checkout/shared-skill directory, proving the complete local review prompt remains available. If snapshots are generated, test deterministic output/freshness with the actual export; do not add a speculative runtime capability or version protocol.
- [ ] Run targeted tests green, search all consumers for old verbose headings/baseline helpers, and commit the coherent deletion and fallback change.

### 4. Verify, stage, review and land

Files: README.md, atlas/modes/review.md, atlas/traceability.yaml, issue/plan Log. The hub owns the ops project record.

- [ ] Update docs to say Couch receives submitted: PATH and the shared skill reads frontmatter and Couch diff; document the outside-Couch inline review separately. Remove old last-send-diff descriptions.
- [ ] Run `make test-spec SPEC=modes/review`, `make check-vocabulary`, any landed export freshness check, and `git diff --check`.
- [ ] Publish with `sdlc pr`, then record the full suite once with `sdlc local-check run --name suite`; keep the pinned-head status/log.
- [ ] Stage through `sdlc stage --build` under hub coordination. The live check submits a process-instruction file, verifies the exact submitted-only delivery and skill-driven response, edits/resubmits to verify changes-since-last-read handling, and exercises outside-Couch inline review in an isolated fixture.
- [ ] Close with concrete evidence, address the binary-owned mandatory review, land on SHIP using `sdlc merge --yes`, clear any leftover stage, and report the PR/outcome to the hub.

## Revisions

### 2026-10-15 16:25 — approved submitted-only contract

Reason: ops:0 chose submitted-only in delivery 9111a425-a6cd-4098-9138-009139f4155c, citing the operator's direction that the agent can compute the diff and submission should rely on the skill. Plan approved with this change.

Delta: replace the proposed S1 payload adapter and capability-dependent messages with unchanged submitted: PATH for every Couch submit. Remove editor-side diff/baseline and verbose message construction. #399 reads process-instruction and computes changes since last read through Couch; retain canonical inline review only outside Couch. The prior plan's last-send semantics, byte-budget builder, capability probes and adapter callbacks are cancelled, not deferred.

The complete original proposal is preserved verbatim in [the superseded proposal](000319-universal-review-send-proposal.md). This revision is the executable plan. No implementation has started; dependencies #399/#332 remain unlanded.

### 2026-10-15 16:35 — provisional #399 consumer pin

Producer pin 8bead12b81f8380757fc55e6e3e90e80bf4fe2d2 is not landed. Export
path: construct/local/universal-review/export.json; schema
ariadne/universal-review-export, version 1, members with role/path/bytes/sha256.
Adapter/mode members have name; grammar has canonical source; modes include
resolved scope/deletions/frontier and optional numeric order. Hashes cover
resolved contents. Total order: round, grammar, adapter, mode; then mode order
(unordered last), name, path. Consumer checks confirmed all nine hashes/byte
counts and six unchanged mode files at this pin.

Local composition is round.md, review-convention.md, selected modes and the
Parley local adapter; exclude SKILL.md and adapters/*. Drop duplicated
Mode.directives prose, passing selected mode data to the canonical round.
Returned two producer-adapter corrections: legacy tracked type must precede
outside-Couch classification, and fold only captured asks reflected in the
write. Export shape is accepted for #319; final consumption still waits for
the landed producer pin and #332. No implementation or live check claimed.

### 2026-10-15 18:01 — landed export and approved independent-first order

Authority: ops:0 delivery e11ea5e9-3fe5-48c2-b152-6f0364faa234. Build the
canonical-export/local-inline portion from main now. Defer old sender removal
and S1-specific tests until #332 lands, then merge main and finish; never base
on #332's branch. This supersedes task 1's requirement to wait for both before
starting independent code. There remains one final review/landing boundary.

#399 landed as ariadne PR #264, f19623c46566c209a1b90c6d95a4714ce61212a9.
Re-read its final export; all nine member hashes/sizes verify and six modes
remain byte-identical. round.md is now 5,058 bytes, sha256
daf90002ea12a41dd7827d4e59dfbe66087f4966ecdc508399c5f909234058ab. Its final
contract excludes the agent's own edits from changes, derives known mode names
from files, defines the frontier/edit region, and treats propose-strike asks as
proposals. Use these landed bytes, not the earlier pin. The TL owns the combined
#332/#399 live acceptance.

Independent implementation detail:
- scripts/sync-review-protocol.py reads the version-1 export and verifies all
  member resolved bytes/hashes before any output write. It snapshots round,
  grammar and modes into lua/parley/skills/review/, plus the source export.json;
  it excludes the Couch adapter from local composition. --source and --output
  are explicit, --check never writes, unsafe/duplicate paths and malformed
  records refuse, and stale generated modes require visible reconciliation.
- Generate SKILL.md from round + grammar, with provenance; keep local-adapter.md
  authored locally and append it AFTER selected mode data in skill.source.
  The adapter requires propose_edits and overrides pane/file IO instructions.
  Named modes arrive as raw name/flag/body values; no second directive prose.
  Preserve the existing no-mode marker-only local invocation with explicit
  parser-default flag values, distinct from a process-instruction free-form
  round. No per-file editor baseline is added to the local invocation.
- Add pure instruction.context(modes, text) for neutral mode data. During this
  independent part keep instruction.brief/Mode.directives for the old Couch
  sender only; delete those duplicate producers with that sender after #332.
- Tests: new tests/integration/review_protocol_bundle_spec.lua exercises the
  generator against portable fixture directories (valid, drifted, malformed,
  unsafe, stale and standalone); tests/unit/review_instruction_spec.lua tests
  context values/order without IO; tests/integration/review_mode_load_spec.lua
  tests real packaged round/grammar -> modes -> local adapter composition and
  unchanged local invocation selection. Extend atlas/traceability.yaml to map
  the new generator fixture test to modes/review.

| Name | Kind | Location | Status | Responsibility |
| --- | --- | --- | --- | --- |
| instruction.context | PURE | lua/parley/skills/review/instruction.lua | new | Neutral selected mode data and operator instruction. |
| sync-review-protocol | INTEGRATION | scripts/sync-review-protocol.py | new | Validated source export to fixed standalone snapshots; check-only freshness. |
| ReviewSource | INTEGRATION | lua/parley/skills/review/init.lua | modified | Existing mode selection plus generated source and final local tool adapter. |

The generated prompt/data additions exceed the quick shell: enter full flow
for plan-quality and derive an estimate only after it passes. Targeted TDD
precedes implementation; full recorded suite and close wait for final S1 work.
