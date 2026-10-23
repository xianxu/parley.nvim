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
| Processing selector and free-text resolution | `lua/parley/skills/review/instruction.lua` | modified |
| Presentation selection | `lua/parley/presentation.lua` | modified |

`editorial_frontmatter.resolve(lines, modes)` returns effective components, warnings and provenance (canonical/legacy/default), with errors separate from text. `fill(lines, modes)` returns either a single insertion patch, a no-op, or a named refusal. It first validates every required component and the complete header shape, then publishes one patch; input tables never mutate. Use `frontmatter` scalar quoting and existing `instruction.parse/resolve` and collaboration parsers rather than duplicating selector/YAML semantics. Existing readers call the shared resolution component they need; avoid circular dependencies by keeping selector resolution beneath editorial resolution, with presentation's independent selection projected from the shared core.

Preserve all original lines verbatim. Detect keys by presence, including empty values, rather than truthiness of parsed scalar values. Duplicate relevant keys, unterminated leading front matter or an unsupported/ambiguous root declaration refuse before additions. Support ordinary root block mappings, unknown nested/block values and legacy collaboration mappings without traversing/re-encoding their values. Key-like text in block scalars, quoted strings, nested values or document body cannot count as a root setting. Relevant non-scalar presentation/processing values need a named validation result, not a guessed string. If the existing parser cannot prove this, extend its shared header scan narrowly with pure tests; do not add a second general YAML parser.

The pure result is local to one submit and dies with it. One document has one projected insertion, regardless of the number of missing keys. Adding a missing key must not change the effective settings that were already resolvable before fill.

### Integration points

| Name | Lives in | Status | Wraps |
|---|---|---|---|
| Registered submit save preparation | `lua/parley/agentic_document.lua` | modified | Existing save effect, authorized buffer edit, normal write, model saved event |
| Outside-Couch review entry | `lua/parley/review_send.lua` | modified | Same projection/edit helper, local invocation and visible routing result |
| Legacy session submit preparation | `lua/parley/session_sync.lua` | modified if needed | Existing `prepare_submit` path; shared helper once, never duplicate fill |
| Protected front matter insertion | `lua/parley/editorial_prepare.lua` | new | Current buffer snapshot and `buffer_edit.edit_user_lines`; no disk writer |
| Runtime settings consumers | `lua/parley/presentation.lua`, `lua/parley/skills/review/instruction.lua`, `lua/parley/review_send.lua` | modified | Canonical/legacy projection, local invoke arguments and round display |

Registered fill belongs inside the accepted **save** effect, after busy/held-press/admission arbitration and before saving or hashing. A busy press joins the existing operation and does not mutate text. Shared preparation returns success/no-op or a concrete refusal, feeds the existing saved failure transition, and prevents register/send on failure. The edit is an ordinary undoable buffer operation through the existing provenance/lock mechanism, never raw set-lines or a direct disk overwrite. A save failure leaves the visible unsaved edit available for undo/retry and sends nothing. No attempt automatically rolls back text after another actor may have edited it.

For outside-Couch ordinary Markdown, validate/prepare using the same pure rules and invoke the local review with effective processing settings; free-form is sufficient, so a missing legacy process-instruction no longer opens a required prompt. Show the existing local-route outcome explicitly. Preserve the local review's selection/marker semantics and direct invocation callers. Typed legacy session files retain their current routing, using shared preparation exactly once before their existing save/send. Do not fall back to local review merely because a known Couch pane's actor lookup failed.

Persistent fake: reuse `tests/helpers/fake_couch.lua`, `tests/fixtures/fake_couch_registry.py` and the native registered-document fixtures. It records registration, owner, sends, receipts, delays and refusals. Assert actual saved bytes, registry identity and notification/band, not mocked function-call counts alone. A temporary read-at-send observation may extend this fake if needed to prove save→register→send ordering.

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

ARCH-DRY: one canonical/legacy resolution owner, existing selectors, registry, save and provenance edit machinery. ARCH-PURE: plain tables in/out for settings and insertion; thin editor shell. ARCH-PURPOSE: both fill and actual reader behavior plus visible outcomes, with both issues' acceptance proved. ARCH-MOCK: persistent fake transport and native editor coverage. ARCH-CONSTRAINTS: linear header work, bounded additions/input and existing submit deadline/concurrency. ARCH-SECURE: document bytes and external replies remain untrusted; malformed/ambiguous metadata becomes a typed refusal, registry replies still pass the existing classifier, no credentials are read or logged, and isolated tests cannot touch operator state. ARCH-ORDER: existing `document_session` transitions remain authoritative; accepted submit emits save, fill failure returns saved-failure with no register/send, success returns the existing saved event, busy press joins/queues under the existing operation, late reply requires its existing exact witness, and detach invalidates the completion. Deterministic delayed fake responses exercise press/fill/save/edit/late-reply sequences. Register/send cannot outlive their existing operation owner; no new background work. ARCH-FUNERAL: creates no new durable file family; only operator-owned document metadata, removed with that document or ordinary undo. No log/cache/watcher is introduced. ARCH-EVOLVE: additive insertions preserve unknown nested fields and existing scalar spellings, with strict ambiguity checks. Mapped tests, indexed atlas and current user-facing key documentation accompany the behavior.

## Implementation tasks — one atomic close, separate issue acceptance

### Task 1: Pin producer contract and prove pure red cases

**Files:** new `tests/fixtures/editorial_fill/` reference copies/provenance; new `tests/unit/editorial_frontmatter_spec.lua`; existing `tests/unit/review_instruction_spec.lua`, `tests/unit/presentation_spec.lua`, `tests/unit/frontmatter_spec.lua`.

- [ ] After #562 lands, fetch its main, verify landed revision and copy all editorial-fill cases with provenance/digests. Normal tests use tracked copies, with no peer-checkout dependency. Check #562's prose and mode metadata through the existing snapshot generator.
- [ ] Add tests of no header, partial header, canonical/legacy component precedence, quoted values/comments, unknown nested data, empty canonical presence, unknown presentation warning/fallback, processing unknown/ambiguous prefix, map preservation, duplicate/unterminated/unsupported root, key-looking block/body literals, and multi-selector whole-document refusal.
- [ ] Assert effective settings before/after additions agree and every old line remains exact; second fill is a no-op. Add mutation controls removing canonical presence precedence, preserving multi-selector refusal and stopping unknown-field rewrites.
- [ ] Run the mapped focused cases and observe RED before implementing the pure projection. Implement only shared resolution/projection, then observe GREEN and commit.

### Task 2: Route real saves and readers through the shared result

**Files:** new `lua/parley/editorial_frontmatter.lua`, `lua/parley/editorial_prepare.lua`; existing `lua/parley/review_send.lua`, `lua/parley/agentic_document.lua`, `lua/parley/session_sync.lua` if its legacy path needs preparation, `lua/parley/presentation.lua`, `lua/parley/skills/review/instruction.lua`.

- [ ] Add native failing cases in `tests/integration/review_send_spec.lua` and registered-document submission specs proving header edit→save→register→one send, non-pane free-form/no required prompt, owner override/current pane rules and actual canonical invoke/display behavior.
- [ ] Cover pending lookup, busy submit, send deadline/late success, save failure, edit refusal, malformed header and retry, reopen and repeated press; assert disk bytes and visible final outcome. A failed fill never registers/sends and leaves bytes unchanged; a failed save never sends.
- [ ] Implement shared editor preparation at existing save admission boundaries. Preserve Child/process ownership from #416 and existing operation/token/receipt logic; no unrelated lifecycle rewrite.
- [ ] Preserve deprecated legacy completion until #419 and update only its changed tests. Update old tests that asserted completely unchanged plain headers to assert preservation plus exact additions.
- [ ] Run focused native cases on both supported runtimes, observe GREEN, inspect diff and commit.

### Task 3: Acceptance, mapping and landing

**Files:** `atlas/modes/review.md`, `atlas/modes/session_sync.md`, `atlas/traceability.yaml`, `TOOLING.md` where behavior is described, both issue details, `workshop/lessons.md` for concrete review findings.

- [ ] Map all new pure/native cases under the existing `modes/review` and affected `modes/session_sync` specs; include arrival, buffer-mutation and source/authoring guards in focused preflight. Update the atlas's current no-header-edit claim and the optional-key examples.
- [ ] Run `make test-spec SPEC=modes/review` and `make test-spec SPEC=modes/session_sync` sequentially in this checkout on preferred Neovim, then with `PARLEY_TEST_NVIM=/opt/homebrew/bin/nvim`. Confirm exact runtime versions first. Run `make lint` and `git diff --check`.
- [ ] Stage via `sdlc stage --build` only when ready for the required operator live acceptance; ask hub to exercise plain/partial documents in ops:0's right pane, owner resolution and visible feedback. Keep artifacts disposable; do not send a live operator message without its specific authorized check. Clear stage afterward unless landing clears it.
- [ ] Push the tested branch. Run one recorded `sdlc local-check run --name affected` if main declares affected policy; otherwise `--name suite`. Retain its runner through completion; classify any failure by name, no blind passing retry.
- [ ] Close #418 and #322 through the binary-owned review with each issue's own verified evidence; follow the binary's combined-issue handling rather than bypass ownership/branch gates. Enter `sdlc merge --yes`, accept its authoritative main integration checks, verify merged/archive evidence and report both outcomes to the hub.

## Acceptance map

**#418:** plain header gains all three explicit defaults, partial header gains only missing effective components, current values/aliases/unknown metadata/body remain exact, later presses/reopen do not re-edit, changes are undoable and saved before submission, and canonical presentation/processing keys actually drive existing runtime consumers. Producer reference cases and both runtimes prove it.

**#322:** plain Markdown in a valid Couch pane reaches that pane's owner after save/register with visible sent-owner/time feedback; lookup/owner/save/edit/validation failures and pending/timeout outcomes are visible and never silently invoke locally. Outside Couch, local review gives an explicit route/no-work/cancel/error outcome and does not require the deprecated process-instruction prompt. A live ops:0 right-pane check confirms the original user-facing path; the original historical prompt route remains evidence, not a route to recreate.
