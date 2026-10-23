---
collaboration-mode: discussion
---

# First-submit front matter and visible submission plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** First Alt+Return fills effective editorial settings without changing existing metadata, then either submits the saved document or gives a visible, actionable outcome.

**Architecture:** One pure canonical/legacy resolver supplies both an additive line-edit projection and existing runtime readers. Existing buffer-edit authorization, registered-document state, save, submit deadline and receipt logic execute that projection; no parallel admission or transport state is added.

**Tech stack:** Lua/LuaJIT, Neovim 0.12.5 and 0.11.7, existing Plenary harness and persistent fake Couch registry.

## Ownership and prerequisite

This is the TL-authorized combined #418/#322 work, on the main-based #418 branch with one shared plan and each card's own Done-when. #322 was wontfix as a #332 duplicate; the 2026-10-23 dispatch explicitly reopens its visible-outcome acceptance. Do not stack either issue on another unlanded branch.

Ariadne#562 owns the canonical prose, mode metadata and source reference fill examples; it supplies no executable filler. Wait for its landing before importing a pinned reference snapshot or claiming conformance. Copy its `construct/local/universal-review/examples/editorial-fill-*` inputs/outputs/case descriptions into Parley test fixtures with the exact landed Git revision and file digests. These are reference oracles, not manifest/API members. Refresh the ordinary dependency from main; never consume the feature branch at runtime. Reuse the normal review-protocol snapshot generator for its declared exported members only.

TL delivery da9d9e00 authorizes migration of existing readers here. Section-comment routing, front matter/heading typeahead, badge conceal and side-doc creation/readers remain #419. This work preserves those comments and legacy maps without translating them. Parley has no session-sync/side-doc front matter creator outside the submit path; its LLM chat templates are a different document family and retain their explicit collaboration choice. #562/#419 own agent-created session/side-doc defaults. No new `type: session-sync`, business `owner:` or guessed `couch-owner:` is injected: Couch's current registry accepts ordinary named Markdown.

## Settled settings and precedence

| Component | Canonical key | Default | Read/fill rule |
|---|---|---|---|
| Collaboration | collaboration-mode | discussion | Existing scalar or legacy section map remains byte-identical; reuse the collaboration resolver. Missing key adds discussion. |
| Presentation | presentation-mode | highlight | Canonical key **presence** wins over legacy presentation. Missing canonical key materializes effective legacy choice. Missing/empty/unknown effective choice is highlight; unknown values warn and remain unchanged. |
| Processing brief | processing-mode | free-form | One stock name or unique prefix, resolved against packaged mode metadata. Missing canonical key takes the legacy leading selector, else free-form. Unknown/ambiguous mode refuses. |
| Free instruction | processing-instruction | absent | Canonical presence independently wins over legacy process-instruction free text. Materialize missing legacy free text when nonempty; never invent an empty instruction. |

Canonical processing-mode and processing-instruction independently override their corresponding legacy components. For example `process-instruction: "[copy-edit] Fix punctuation."` adds `processing-mode: copy-editing` plus `processing-instruction: Fix punctuation.` and retains the legacy line. An explicit canonical instruction takes only the missing legacy mode; an explicit canonical mode takes only missing legacy free text. Keep every existing canonical value, alias, comment, unknown field and body byte; additions are the only rewrite. `review-mode` is ordinary unknown metadata, never an invented alias.

Legacy multi-selector instructions remain readable: all briefs in order, first brief flags, deprecation warning. Automatic fill refuses the entire document before any edit if more than one leading legacy selector would be collapsed; the notice asks for one processing-mode and remaining intent in processing-instruction. Do not silently drop a brief. Existing collaboration maps remain readable, warned and preserved; ordinary fill does not migrate them into heading comments.

Presentation fallback clarification: ariadne:5 delivery 7106eb75 relays TL confirmation 323593d6: missing/empty/unknown front matter presentation-mode means highlight; its presence still defeats the legacy alias. This rule does not weaken processing-mode validation or #419's strict heading declaration validation. Confirm the producer's committed clarification when #562 lands.

## Alternatives

1. **Recommended:** shared pure resolution plus additive projection at existing save boundaries. Existing values become effective and submission retains one owner/deadline.
2. Insert three literal defaults in the key mapping. Reject: shadows legacy intent, bypasses direct submit callers and can edit during an already-issued send.
3. Decode/re-emit all YAML. Reject: loses unknown fields, scalar styles, comments and exact legacy bytes; this feature requires insertion, not normalization.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|---|---|---|
| Effective document editorial settings and additive fill projection | `lua/parley/editorial_frontmatter.lua` | new |
| `resolve`, `fill`, `presentation_value` — effective components, additive projection and independent repaint selection | `lua/parley/editorial_frontmatter.lua` | new |
| `header`, `scalar` — bounded root presence and owned scalar decoding | `lua/parley/skills/review/collaboration_value.lua` | new |
| Processing selector and free-text resolution | `lua/parley/skills/review/instruction.lua` | unchanged, reused |
| Presentation selection | `lua/parley/presentation.lua` | modified |
| Owned preparation and submission lifecycle | `lua/parley/document_session.lua` | modified |

`editorial_frontmatter.resolve(lines, modes)` returns effective components, warnings and provenance (canonical/legacy/default), with errors separate from text. `fill(lines, modes)` returns either a single insertion patch, a no-op, or a named refusal. It first validates every required component and the complete header shape, then publishes one patch; input tables never mutate. Use `frontmatter` scalar quoting and existing `instruction.parse/resolve` and collaboration parsers rather than duplicating selector/YAML semantics. Existing readers call the shared resolution component they need; avoid circular dependencies by keeping selector resolution beneath editorial resolution, with presentation's independent selection projected from the shared core.

Preserve all original lines verbatim. Detect keys by presence, including empty values, rather than truthiness of parsed scalar values. Duplicate relevant keys, unterminated leading front matter or an unsupported/ambiguous root declaration refuse before additions. Support ordinary root block mappings, unknown nested/block values and legacy collaboration mappings without traversing/re-encoding their values. Key-like text in block scalars, quoted strings, nested values or document body cannot count as a root setting. Relevant non-scalar presentation/processing values need a named validation result, not a guessed string. If the existing parser cannot prove this, extend its shared header scan narrowly with pure tests; do not add a second general YAML parser.

The pure result is local to one submit and dies with it. One document has one projected insertion, regardless of the number of missing keys. Adding a missing key must not change the effective settings that were already resolvable before fill.

### Integration points

| Name | Lives in | Status | Wraps |
|---|---|---|---|
| Registered submit preparation lifecycle | `lua/parley/document_session.lua` | modified | Existing operation witness with explicit preparation stage before ordinary save |
| Registered submit editor execution | `lua/parley/agentic_document.lua` | modified | Preparation projection, real edit observer, authorized buffer edit, normal write and model events |
| Outside-Couch review entry | `lua/parley/review_send.lua` | modified | Same projection/edit helper, local invocation and visible routing result |
| Legacy session submit preparation | `lua/parley/session_sync.lua` | modified if needed | Existing `prepare_submit` path; shared helper once, never duplicate fill |
| Protected front matter insertion | `lua/parley/editorial_prepare.lua` | new | Current buffer snapshot and `buffer_edit.edit_user_lines`; no disk writer |
| Runtime settings consumers | `lua/parley/presentation.lua`, `lua/parley/review_send.lua` | modified | Canonical/legacy projection, local invoke arguments and round display |
| Processing primitive reuse | `lua/parley/skills/review/instruction.lua` | unchanged, reused | Existing parse/resolve/context semantics remain authoritative |

Registered fill belongs in an explicit **prepare** stage of the existing accepted submit operation, before ordinary save. The previous proposal to edit inside save is retired: `agentic_document.lua`'s real on_lines observer dispatches changed while busy, and `document_session.lua` cancels save on that event. Retain that ordinary invalidation behavior rather than suppressing the observer. A busy press joins the same operation and does not mutate text. Preparation failure ends that operation visibly and permits no save/register/send. The edit remains an ordinary undoable operation through existing provenance/lock machinery, never raw set-lines or a direct disk overwrite. A save failure leaves the visible unsaved edit available for undo/retry and sends nothing; no automatic rollback over another edit.

### Owned preparation protocol (PQ-1)

The single model operation is the resource covering preparation through delivery. Its preparation record carries the normal exact path/namespace/incarnation/generation/token witness plus tagged stage and expected before/after content hashes; no independent ignore-change flag is introduced. The shell still reports every real buffer event and increments its normal revision/baseline bookkeeping. Only the exact expected one-edit transition may stay within preparation; arbitrary changed/reload/context/detach events retain their cancellation behavior. Rejected or stale preparation completions cannot save. The model-to-shell protocol is:

| Model state + event | Model result/effect |
|---|---|
| idle + accepted submit | issue prepare with stage planning and original submit args |
| planning + projected (matching witness; successful pure plan and current preimage) | retain before/after hashes and stage awaiting-edit; emit apply-preparation; a no-op projection goes directly to ordinary save |
| awaiting-edit + observed edit (matching witness and exact before/after hashes) | stage observed-edit, keep the operation; no save yet |
| awaiting-edit + different edit, or any second edit | existing changed invalidation/cancel; no save/register/send |
| observed-edit + prepared (matching live witness, successful authorized edit, current postimage) | issue existing save with original submit args |
| planning/awaiting-edit/observed-edit + refusal, changed context, reload or detach | terminate/cancel under existing model semantics with named failure; ignore late completion |
| save + ordinary changed / saved | retain existing changed cancellation / saved transition and downstream registry/send protocol |

The thin shell captures the pure projection and expected hashes before applying the one insertion. `on_lines` supplies its actual previous/current hash as an observed-edit candidate only while the model is preparing; the model validates that candidate, not a broad shell boolean. A mismatched edit follows changed invalidation. After the authorized API returns, fresh buffer identity and content must still match the expected postimage before prepared is dispatched; a reentrant unrelated edit before, during or after the insertion prevents advancement. Native reload always invalidates rather than masquerading as a prepared edit. A failed edit without the expected observation cannot be acknowledged. Ordinary byte-exact no-op preparation requires no observer event. Keep all authorization/projection knowledge on the existing operation record; it dies with cancellation/detach/completion. Native tests must verify the actual observer and provenance API execute this protocol on both runtimes before treating the seam as established.

For outside-Couch ordinary Markdown, validate/prepare using the same pure rules and invoke the local review with effective processing settings; free-form is sufficient, so a missing legacy process-instruction no longer opens a required prompt. Show the existing local-route outcome explicitly. Preserve the local review's selection/marker semantics and direct invocation callers. Typed legacy session files retain their current routing, using shared preparation exactly once before their existing save/send. Do not fall back to local review merely because a known Couch pane's actor lookup failed.

Persistent fake: reuse `tests/helpers/fake_couch.lua`, `tests/fixtures/fake_couch_registry.py` and the native registered-document fixtures. It records registration, owner, sends, receipts, delays and refusals. Assert actual saved bytes, registry identity and notification/band, not mocked function-call counts alone. A temporary read-at-send observation may extend this fake if needed to prove save→register→send ordering.

### Native preparation API

| Name | Lives in | Status |
|---|---|---|
| `project`, `apply`, `prepare` — capture compact witnessed insertion, authorize/apply once, and reuse outside registered submission | `lua/parley/editorial_prepare.lua` | new |

## Actions and visible states

Actions: Alt+Return, edit the named setting/file, undo, save/resolve permissions, wait for an issued send, retry Alt+Return.

| Internal state / failure mode | Visible state | Recovery action | Possible loss |
|---|---|---|---|
| No/partial valid header; admission accepted | preparing/submitting, then sent owner/time | wait | only additive undoable metadata edits |
| All fields present / repeated idle press | existing receipt or nothing-to-submit | normal Alt+Return/resend contract | none; no header edit |
| Multi-mode legacy fill, invalid processing mode, ambiguous header | named setting error; nothing submitted | edit named setting, Alt+Return | none; zero bytes changed |
| Deprecated alias or unknown presentation fallback | warning plus ordinary submit result | optional edit to canonical setting | no alias/value erased |
| Buffer edit/protection refused | named refusal; nothing submitted | resolve protection and retry | none |
| Save failed after fill | visible save failure; buffer remains modified | undo or save/resolve permissions, retry | only current unsaved additions |
| Pane actor unresolved / registry unavailable | existing failed/not-confirmed feedback | retry Alt+Return | no speculative rerouting |
| Send pending or deadline unknown | existing submitting/not-confirmed state | wait or existing explicit retry | delivery remains uncertain; no duplicate queued |
| Local review route | explicit running-here result, or named validation/cancel/no-work result | edit/retry as named | no peer send |

The existing per-document in-flight operation is the single resource that prevents concurrent saves/submits; no new boolean history cache is needed. Idempotence comes from current header presence, not a remembered first-submit flag, so reopening still behaves correctly.

## Costs, persistence and architecture

Let B be document bytes, H header bytes and K packaged mode count. One fill scans the supplied header once, resolves K names once, and inserts at most four lines plus fences. Avoid one full-document parse per missing key; assert counted header visits for N and 2N headers and no extra edits on the second fill. This is a submit-time editor operation, not a repaint or keystroke hook. Proposed input envelope: at most 8192 front matter lines / 1 MiB of header text (domain assumption for interactive metadata); exceeding it refuses visibly before edits. Body size keeps the existing submit/hash envelope; no full body rescan per missing setting. Exercise boundary/refusal tests and a representative large header on both runtimes. Per-keypress completion work is outside this plan. Reuse mode metadata loaded through the existing owner rather than new filesystem scans in rendering callbacks.

ARCH-DRY: one canonical/legacy resolution owner, existing selectors, registry, save and provenance edit machinery. ARCH-PURE: plain tables in/out for settings and insertion; thin editor shell. ARCH-PURPOSE: both fill and actual reader behavior plus visible outcomes, with both issues' acceptance proved. ARCH-MOCK: persistent fake transport and native editor coverage. ARCH-CONSTRAINTS: linear header work, bounded additions/input and existing submit deadline/concurrency; native content proofs add constant O(B) hashes, never one body scan per key. ARCH-SECURE: document bytes and external replies remain untrusted; malformed/ambiguous metadata becomes a typed refusal, registry replies still pass the existing classifier, no credentials are read or logged, and isolated tests cannot touch operator state. ARCH-ORDER: the owned preparation protocol above and existing `document_session` transitions remain authoritative; no observer suppression or parallel operation owner. Register/send cannot outlive their existing operation owner; no new background work. ARCH-FUNERAL: creates no new durable file family; only operator-owned document metadata, removed with that document or ordinary undo. No log/cache/watcher is introduced. ARCH-EVOLVE: additive insertions preserve unknown nested fields and existing scalar spellings, with strict ambiguity checks. Mapped tests, indexed atlas and current user-facing key documentation accompany the behavior.

## Function verification strategies (PQ-2)

| Risky function / seam | Adversarial input class and mechanical guard |
|---|---|
| Shared header scanner in `frontmatter.lua` | Generated root/nested/block/quoted/body syntax and malformed delimiters: prove relevant key presence cannot be forged by literal text; refuse ambiguity without changing any input, with counted N/2N scans and explicit bounds. |
| `editorial_frontmatter.resolve(lines, modes)` | Generated canonical/legacy component combinations: independent effective-value oracle plus pinned producer references rejects shadowing and dropped instruction intent; preserve the documented presentation fallback. |
| `editorial_frontmatter.fill(lines, modes)` | Generated future metadata and scalar spellings: exact old-byte subsequence/body invariants, idempotence and zero-change refusals; mutation controls remove precedence or refusal guards and must turn red. |
| `instruction.resolve/expand` and canonical component resolution | Generated mode catalogs/prefix collisions and multi-selector legacy values: compare selection/order/flags and refusal against an independent catalog oracle, not a second call to the same resolver. |
| `presentation.value(lines)` | Generated canonical-presence/alias combinations: fixed truth table and returned warning prove fallback uses selected key presence; exact source preservation is asserted separately by fill. |
| `document_session.new(...).dispatch(event)` | Generated preparation/edit/save/detach event sequences with exact/stale witnesses: no save before proved preparation, exactly one ordinary save after it, no later send after interruption; existing duplicate/late-send invariants remain. |
| `editorial_prepare` + real `agentic_document` on_lines/submit/execute | Native observer plus controlled reentrant edits and delayed fake registry replies: assert expected insertion advances, unrelated edits invalidate, undo/save bytes and actual sends agree with model effects. No observer mock or generic mute flag can satisfy the test. |
| `review_send.submit` and legacy `session_sync.prepare_submit` | Native public mappings with persistent fake Couch and local invocation capture: require a visible route/outcome, exact saved bytes before delivery and no external send after edit/validation/save refusal. |

## Implementation tasks — one atomic close, separate issue acceptance

### Task 1: Pin producer contract and prove pure red cases

**Files:** new `tests/fixtures/editorial_fill/` reference copies/provenance; new `tests/unit/editorial_frontmatter_spec.lua`; existing `tests/unit/review_instruction_spec.lua`, `tests/unit/presentation_spec.lua`, `tests/unit/frontmatter_spec.lua`.

- [x] After #562 lands, fetch its main, verify landed revision and copy all editorial-fill cases with provenance/digests. Normal tests use tracked copies, with no peer-checkout dependency. Check #562's prose and mode metadata through the existing snapshot generator.
- [x] Implement the named pure-function strategies above in their mapped tests, using pinned producer cases and generated malformed-header/preservation oracles; prove each regression red before the corresponding implementation.
- [x] Run the mapped focused cases and observe RED before implementing the pure projection. Implement only shared resolution/projection, then observe GREEN and commit.

### Task 2: Route real saves and readers through the shared result

**Files:** new `lua/parley/editorial_frontmatter.lua`, `lua/parley/editorial_prepare.lua`; existing `lua/parley/review_send.lua`, `lua/parley/agentic_document.lua`, `lua/parley/document_session.lua`, `lua/parley/session_sync.lua` if its legacy path needs preparation, `lua/parley/presentation.lua`, `lua/parley/skills/review/instruction.lua`.

- [x] Implement the named lifecycle/native strategies above in `tests/unit/document_session_spec.lua`, `tests/integration/review_send_spec.lua` and registered-document submission specs. Use controlled production events and the real buffer observer to make interruption order reproducible; observe the expected failures before changing the model/IO seam.
- [x] Implement the approved owned preparation protocol before ordinary save, with the same operation witness and no observer suppression. Preserve Child/process ownership from #416 and existing registry/send/receipt logic; no unrelated lifecycle rewrite.
- [x] Preserve deprecated legacy completion until #419 and update only its changed tests. Update old tests that asserted completely unchanged plain headers to assert preservation plus exact additions.
- [x] Run focused native cases on both supported runtimes, observe GREEN, inspect diff and commit.

### Task 3: Acceptance, mapping and landing

**Files:** `atlas/modes/review.md`, `atlas/modes/session_sync.md`, `atlas/traceability.yaml`, `TOOLING.md` where behavior is described, both issue details, `workshop/lessons.md` for concrete review findings.

- [x] Map all new pure/native cases under the existing `modes/review` and affected `modes/session_sync` specs; include arrival, buffer-mutation and source/authoring guards in focused preflight. Update the atlas's current no-header-edit claim and the optional-key examples.
- [x] Run `make test-spec SPEC=modes/review` and `make test-spec SPEC=modes/session_sync` sequentially in this checkout on preferred Neovim, then with `PARLEY_TEST_NVIM=/opt/homebrew/bin/nvim`. Confirm exact runtime versions first. Run `make lint` and `git diff --check`.
- [x] Stage via `sdlc stage --build` only when ready for the required operator live acceptance. The hub schedules the operator's check on a session document (approval 7acabe36), covering plain/partial front matter, owner resolution and visible feedback for the original pane submission path. Keep artifacts disposable; do not send a live operator message without its specific authorized check. Clear stage afterward unless landing clears it.
- [x] Push the tested branch. Run one recorded `sdlc local-check run --name affected` if main declares affected policy; otherwise `--name suite`. Retain its runner through completion; classify any failure by name, no blind passing retry.
- [ ] Close #418 and #322 through the binary-owned review with each issue's own verified evidence; follow the binary's combined-issue handling rather than bypass ownership/branch gates. Enter `sdlc merge --yes`, accept its authoritative main integration checks, verify merged/archive evidence and report both outcomes to the hub.

## Acceptance map

**#418:** plain header gains all three explicit defaults, partial header gains only missing effective components, current values/aliases/unknown metadata/body remain exact, later presses/reopen do not re-edit, changes are undoable and saved before submission, and canonical presentation/processing keys actually drive existing runtime consumers. Producer reference cases and both runtimes prove it.

**#322:** plain Markdown in a valid Couch pane reaches that pane's owner after save/register with visible sent-owner/time feedback; lookup/owner/save/edit/validation failures and pending/timeout outcomes are visible and never silently invoke locally. Outside Couch, local review gives an explicit route/no-work/cancel/error outcome and does not require the deprecated process-instruction prompt. A live ops:0 right-pane check confirms the original user-facing path; the original historical prompt route remains evidence, not a route to recreate.

## Revisions

### 2026-10-23 — approved design and scheduled live acceptance

TL approval 7acabe36-c3b8-4c2a-b70f-33d8f62d5788 accepts this design and bounds, with change-code after #562 lands and its fixtures can be pinned. The hub schedules live acceptance with the operator on a session document; no worker-initiated live send or unscheduled operator test is authorized by this plan. Confirm the original pane path through that scheduled check rather than assuming a slot/location beforehand.

### 2026-10-23 — plan review round 1: owned preparation before save

PQ-1 verified that the original insertion-inside-save proposal is invalid: the real edit observer dispatches changed while busy, and the pure model cancels save, ignoring its later saved event. Retire that proposal in place. Add the explicit witnessed preparation stage to the same operation; only its exact projected edit is recognized, while every unrelated edit/reload/detach still invalidates. This design delta goes to TL before the next gate run. PQ-2 replaces case inventories with named function strategies and generated/adversarial mechanical guards. TL delivery b47c8af9 also confirms per-span presentation round consumption belongs to #419; #418 remains whole-document.

### 2026-10-23 — implementation ownership and bounded scan accounting

The shared root-mapping scanner lives in collaboration_value.lua, whose existing quoted/flow/nested handling is reused rather than adding a second parser to frontmatter.lua (ARCH-DRY). The actual implementation performs a constant number of bounded header scans: input shape/presence, existing collaboration resolution, and projected-header validation when inserting. It never scans once per missing key. The N/2N mechanical guard counts executed Lua VM instructions with JIT disabled, including the existing routing pass over the body, instead of a self-reported scan counter; its ratio rejects quadratic growth. Native hashes remain a constant number of whole-buffer passes. Both input and resulting metadata include opening/closing fences in the approved 8192-line / 1-MiB envelope. Existing instruction.parse/resolve already supplies the selector primitive and remains unchanged; canonical component selection belongs in the new shared resolver. Runtime operation payloads retain only the small executable patch and effective settings, not parsed header trees, full postimages or body routing tables.

### 2026-10-23 — exported API inventory checkpoint

The architecture sweep found that the Core-concepts table described the modules but omitted exact names for their new public functions. Added the eight existing API names and classified project/apply/prepare as native IO. This documents the implemented approved mechanism; no runtime scope changes.

### 2026-10-23 — live acceptance completed

TL delivery 3b3b276e reports operator acceptance passed at 09:25 and directs close/landing for #418 and #322. Staging and its live check are complete. The final close/merge workflow checkbox remains pending until those gates actually finish; each issue's implementation acceptance checklist now distinguishes that future gate from completed behavior proof.

### 2026-10-23 — close round 1: scalar round-trip and root layout

BR-1 requires materialized strings to retain their YAML string type and decoded contents, including internal control/line-break characters, on the next resolve/fill. Reuse the owned scalar reader to test plain-value round-trip and quote unsafe values through a JSON-compatible YAML string encoding with escaped controls; ordinary safe fixture values remain plain. Enumerate implicit scalar types, numeric/date-like values, quote/comment punctuation, escaped text and Unicode line controls in pure tests, plus real native insertion/save/send coverage. Do not rewrite existing alias or metadata lines.

BR-2 requires additions to use the existing root mapping's indentation, rather than changing its layout and failing projected validation. Derive that indentation from the scanner's existing first root entry; preserve all old rows, test widths 1–4 with nested/literal/legacy fields, and require idempotent output and native submission.

BR-3 corrects both Core-concepts inventory rows for instruction.lua: the selector module is unchanged and reused, as its empty pinned diff and earlier implementation note establish. Runtime consumer changes are confined to presentation.lua/review_send.lua; no acceptance or scope changes.
