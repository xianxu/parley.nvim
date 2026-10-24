# Collaborative chat interface implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development for bounded independent tasks or superpowers-executing-plans for work depending on warm context. Steps use checkbox syntax for tracking.

**Goal:** recognize and preserve `@@chat@@` sections, consume the mode-free v4 review contract, and make monthly side-document links work without adding a local multi-document writer.

**Architecture:** one snapshot projection supplies chat structure to pure policy and existing effect owners. Existing skill invocation writes the submitted document, tags stay ordinary text, entity operations own section edits, document_move owns recursive moves, and agentic_document owns registration. The agent classifies questions versus commands; a validated local proposal preserves question markers before the existing edit tool runs.

**Tech stack:** Lua/LuaJIT, Neovim 0.12.5 and 0.11.7, bundled Markdown Tree-sitter structural adapter, Python standard-library export synchronizer, Plenary/native embedded-Neovim tests.

**Status:** TL approved 2026-10-23 (ad007bf0); change-code passed. Later TL b8c4f2df removes optional tint; #434 holds the unclaimed future feature.

## Source and allocation

- Policy/fixtures: landed ariadne#576 / PR420, Git `354e5fac5c96e0b2c26350ee712eb835746a6d67`, `construct/local/universal-review/{export.json,round.md,collaboration-modes.md,examples}` and `pkg/sidedoc/chat.go`.
- New policy is one collaborative behavior, no mode keys or standing instruction, and highlight for new agent edits. Preserve old metadata; notices are verbatim from the pinned parser/examples.
- TL 3d546ddc: outside Couch remains single-buffer. Questions remain untouched with `questions are answered in a side doc by Couch review; left unchanged`; commands still apply. Couch's agent review owns multi-document side/answer docs, follow-ups, decisions, folds and index writes.
- Pair #838 is unlanded (pair:3). No stacking, runtime import or dependence on its proposed Read.Editorial shape. Existing round JSON is the integration seam.
- Historical compatibility oracle: landed Pair #823 `cmd/internal/sessionsync/testdata/editorial-rounds/presentation.json`. Verify its landed Git object and record provenance at import; do not use it as new policy guidance. Stored span presentation > stored round presentation > highlight; never current document frontmatter. New Couch writes stamp highlight.
- #418's delivered parser correction and #322's mode-free submit dispatch stay in place. No second save/submit owner and no resurrected fill/preparation state.

## Alternatives and recommendation

1. **Recommended:** share one structural snapshot/projection; thin existing consumers apply it. Use explicit local question deferral and preserve historical round values. This makes tags, admission and moves agree and keeps the established IO owners.
2. Independent tag patterns in each consumer are smaller initially but generic tag stripping, literal exclusions, section ends and duplicated headings would disagree. Reject (ARCH-DRY).
3. A local side-doc writer would align every outcome with Couch but adds allocation, multi-file recovery and a second write owner. TL explicitly rejected that scope; document the supported local exception instead.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|---|---|---|
| ChatScan / chat-item projection: `scan`, `items` | `lua/parley/skills/review/chat_policy.lua` | new |
| Legacy chat evidence decoder: `header`, `evidence` | `lua/parley/skills/review/collaboration_value.lua` | modified |
| Local proposal validation: `validate` | `lua/parley/skills/review/local_proposal.lua` | new |
| Flagless brief manifest/body loader: `list`, `load`, `context` | `lua/parley/skills/review/brief.lua` | new |
| Old mode and standing-instruction flags | `lua/parley/skills/review/mode.lua`, `instruction.lua` | deleted |
| Side-document path relationship: `month`, `member`, `root`, `parent`, `relation` | `lua/parley/side_document_path.lua` | new |
| Historical span presentation projection: `effective` | `lua/parley/presentation.lua` | modified |

- **ChatScan:** `{sections, headings, tags, misplaced, notices}`; submitted-document 1-based lines, inclusive section end, heading 0 means whole document. Each section has `{heading, finish, source, legacy}`. A heading has source row, level, name and ATX/setext kind. Sections are nested/disjoint; a stack projects innermost section once per row. Tag coordinates remain available even under a whole-document legacy scalar. Pure core receives typed structural facts, never Neovim nodes. Unit-test with plain tables.
- **Items:** separate operator-owned item extents from ready robot-marker asks inside chat. Tag grammar uses numbered `N.` items; legacy also `-`/`*`; tab stops, shallowest list indentation, continuations, prose breaks and answered links follow the pinned source. Each line is visited a constant number of times. Do not blanket-filter every marker in chat.
- **Legacy evidence:** reuse the existing bounded scalar/map decoder and root-plain correction. Preserve known block/flow chat maps and quoted/plain strings. Errors become exact visible unread/malformed notices, never admission failure. Retired keys do not enter an interpretation pipeline. Do not grow a general YAML scanner: if supported legacy forms cannot match the pinned oracle, stop and bring the smallest mismatch to TL before adding syntax. Empty presence differs from missing; only a closed leading fence block can emit unread-frontmatter.
- **Local proposal:** agent semantics remain agent-owned. Require each ready marker to be identified exactly once by `{line, col, raw, kind}` (zero-based line and byte column, matching parse_markers) in a review-only classification envelope, with `kind=command|question` (unclear/unsure resolve question). Coordinates and bytes bind it to this invocation snapshot. Question spans become protected; only declared command work may be applied. Missing/duplicate/stale/malformed classification refuses the complete local batch before any effect. Reject proposed edits that replace deferred questions or protected tag/heading/item/frontmatter bytes. No punctuation-based question detector.
- **Brief loader:** names and bodies derive only from manifest role `brief`. Validate flag absence and name-only frontmatter; retire free-form. Load the five small brief bodies with the source so the agent can infer the applicable brief from the current ask. No mode args, bracket selectors, flags or standing instruction. No new completion list.
- **Side path relation:** pure normalized path helpers distinguish flat and one-month layouts, derive one owning `.side` root, and accept a child opened from its actual parent only after its declared `parent:` resolves correctly under that root. No basename-only proof; no nested `.side` root for a side doc. Reuse `side_tree_model` parent-chain/cycle rules. The relationship does not itself grant Couch ownership.
- **Historical presentation:** validate known values, absent fallback only, preserve unknown JSON members by leaving persistence with the existing producer. Render stored direct as no tint, highlight as tint, propose as existing marker content. New local edits always highlight. No document key can suppress or reinterpret a stored round.

### Integration points

| Name | Lives in | Status | Wraps |
|---|---|---|---|
| Local admission integration: `validate_edits` | `lua/parley/skills/review/collaboration.lua` | modified | snapshot, policy and proposal guard |
| Markdown structure adapter: `snapshot` | `lua/parley/skills/review/chat_structure.lua` | new | bundled string parser; immutable line snapshot |
| Review invocation: `run_via_invoke` | `lua/parley/skills/review/init.lua`, `lua/parley/skill_invoke.lua` | modified | existing provider/tool/apply/reload lifetime |
| Bounded review notices: `show` | `lua/parley/review_notice.lua` | new | existing message history and notifier |
| Review proposal schema | `lua/parley/tools/builtin/propose_edits.lua` | modified | optional review classification metadata; same write tool |
| Packaged protocol synchronizer | `scripts/sync-review-protocol.py` | modified | pinned Git source, digest/path checks, owned output |
| Tag recognition / consumers: `review_tags`, `review_tags_for_buffer`, `apply_outline` | `highlighter.lua`, `question_tags.lua`, `reference_candidates.lua`, `outline.lua`, `document/lexical.lua` under `lua/parley/` | modified | existing document/viewport lifecycle |
| Section operations | `lua/parley/entity_range.lua`, `entity_textobj.lua` | modified | existing native edits/moves |
| Side-doc discovery/inheritance | `lua/parley/attention.lua`, `agentic_document.lua` | modified | directory scans, actual-parent header, existing Couch model |
| Existing recursive mover | `lua/parley/document_move.lua`, `document_move_plan.lua` | modified if tests expose gap | existing journal/reconciliation |
| Round display | `lua/parley/edit_round.lua`, `skill_render.lua` | modified | existing round request generation and extmarks |

**Structure boundary:** parse one string snapshot with Markdown grammar, extract heading/code/source ranges in one traversal, then call the pure policy. Keep the established outline/editing H1–H3 dialect unchanged: tag ownership only widens extents of an already supported editing heading. ATX H4–H6 and setext still define review policy. No guessed title-based attachment. If the bundled parser is unavailable, refuse local command execution requiring a policy proof visibly; Couch submit and ordinary rendering remain available. Test this explicit degraded state; do not silently use a different grammar.

**Proposal boundary:** add optional `review_asks` metadata to the existing propose_edits schema; other tools/callers remain unchanged. Extend the existing pre-effect `validate_edits(snapshot, edits, input)` hook to receive complete input. Review requires exactly one proposal and complete typed classification; validates the whole batch before launching the existing tool producer. No new tool executor, state machine or write authority. Completion derives the deferral notice from that validated snapshot result; all-question rounds do not auto-resubmit endlessly. Preflight all calls before any producer starts; denied or missing-proposal responses complete as failure without reload. A no-op question batch completes successfully before tool dispatch/readback/reload/render/journal/projection, checking resolve_user(source_capture) plus existing generation so ABA edits invalidate it. Emit notices only from current successful on_done. Stop automatic resubmission whenever deferred questions remain. A no-op question batch must not create backups or write the source. Preserve generic skill callers that do not install the review hook.

**External seams/fakes:** reuse existing provider/tasker response fixtures, async tool producer/file authority, filesystem-backed fake_couch and embedded editor fixtures. Do not use the live fleet for automated tests. Actual provider output is untrusted; classification is a model decision, while coverage, identity, protection and scope are deterministic validation. A malicious model could misclassify a question as a command; this semantic limit is explicit and matches the shared agent contract. Live checks cover ordinary wording and mixed asks.

## Actions, visible states and recovery

Actions: edit/save; submit locally; submit in Couch; reopen/follow link; move/rename; undo; cancel/retry the current invocation.

| Internal state / failure mode | Visible state | Recovery action | Possible loss |
|---|---|---|---|
| Valid tag/legacy chat evidence | Ordinary visible tag; legacy notice on review | Edit/save | None; old metadata retained |
| Misplaced tag or retired/malformed key | Exact notice; ordinary collaborative interpretation | Edit/save | No text loss; malformed metadata provides no policy |
| Local command plus question | Command edit highlighted; question unchanged and limitation notice | Submit in Couch | None; question intentionally deferred |
| Local question only / chat item only | Unchanged source; Couch limitation notice | Submit in Couch | None; no local answer/file allocated |
| Unclassified/malformed/stale provider proposal | Visible refusal, no batch effects | Retry current invocation | Provider output discarded, operator text kept |
| Edit/reload/context switch/cancel before completion | Existing cancelled/stale invocation outcome | Submit again | Existing externally completed disk effects follow current reconciliation path |
| Markdown grammar unavailable | Decoration skipped visibly; local guarded edit unavailable | Submit in Couch | No text loss; no fabricated structural proof |
| Side file missing/unreadable / parent invalid | Existing navigation/inheritance unavailable result | Reopen/follow link after repair | No automatic reparenting or deletion |
| Move partially applied / Couch result uncertain | Existing document_move recovery state | Existing retry/reopen action | Existing journal preserves partial progress; no new rollback claim |
| Historical mixed round | Original effective per-span rendering | Submit next round | New successful round normally supersedes prior display |

This adds snapshot data and a proposal validation contract, not another operation lifetime. The existing skill generation/cancellation/read owner, document edit witness, move journal and agentic model continue to arbitrate effects. Late completions must not display notices into a replacement buffer or start another write. Sequence tests pause before validation, after tool dispatch and before reload; edit, cancel, detach and retry there.

## Operating envelope and growth

- Submit-time snapshot cost: bytes B, lines L, headings H, legacy names K, ready asks A and proposed edits E. One Markdown parse/traversal, one legacy-header scan, one section stack and one item pass. Target O(B+L+H+K) policy work, memory O(B+L+H+K). Count node/byte/line/stack visits at N/2N (e.g. 64/128 headings, mixed fences/items) and reject >2.5x work plus a fixed allowance; parser's native parse cost is separately measured as in the source oracle.
- Never call a whole-document policy parse per heading, visible row or edit. Capture one projection per admission pass or navigation/section operation and carry it through its consumers. Proposal completion revalidates its immutable invocation snapshot once, never once per edit. There is no render-time semantic parse: tags stay ordinary text. The highlighter retains its existing 256-row/64KiB viewport budget and only excludes the literal standalone review tag from generic local-tag styling. Reuse the document's invalidation/snapshot boundary rather than add a watcher or persistent policy cache. Tests count parser calls for N/2N visible rows and one batch of edits.
- Retain existing round cap 200 spans and recursive move limits 4096 entries /512 Markdown files. Existing unique edit matching remains bounded by the invocation's snapshot; do not claim linear aggregate edit matching if it still searches once per edit.
- Attention: at most its existing 256 tracked roots, deduplicate owning roots before scanning. Accept only direct flat `.md` and one `YYYY-MM` directory level, no arbitrary recursion/symlink descent. Scan each selected owning root once per refresh; read headers only for selected mtime events, retain existing 40-line side-doc header limit. Count directory visits at N/2N months/files and shared-root tracked entries. Unknown/unreadable directory state must not delete attention records or mint ownership.
- No network/parser work on a per-byte callback and no new process, timer, machine-global path or machine setting. UI effects use the existing scheduled/bounded owners. Explicit local review and section operations admit at most 1 MiB (existing source-read cap), checked before reading/allocating a full snapshot; beyond it refuse that guarded local action visibly and preserve Couch submission. Full-doc parse on submit is outside the keystroke path. Optional tint and its failed latency qualification moved to unclaimed #434 by TL b8c4f2df; no tint admission limits or timing tests remain runtime requirements here.

## Trust, compatibility and residue

ARCH-SECURE: files, legacy YAML, paths, manifests and provider/Couch replies are untrusted. Keep digest/path/symlink checks before sync writes; classify known fields at the boundary. Side inheritance proves actual parent plus owning-root relationship then asks the existing Couch owner; a matching dirname alone is insufficient. Tests use scratch roots and isolated fake Couch, never real user docs. No credentials created or logged.

ARCH-EVOLVE: v4 is a producer-declared semantic break: old mode flags cannot safely interpret flagless briefs. Upgrade generated bundle and consumers in one issue commit group, preserve local Lua/adapter files outside synchronizer ownership, refuse unsupported versions before IO. Retain legacy document bytes; readers adapt without migration. Round projection reads old fields; no new round/review-record persistence owner. If a rewrite is required by integration, preserve nested unknown raw fields and exact JSON numeric text, with codec tests before shipping it.

ARCH-FUNERAL: no runtime cache, ledger, watcher, process or side-doc family added. Snapshot projections die with their operation; existing extmarks die on refresh/unload and clear their namespace only. Imported fixtures/briefs are finite version-controlled members; remove stale generated modes explicitly after validation. Existing side docs are operator documents with deliberate indefinite retention under the contract; this issue adds no per-event creation. The mover's old journal/backups retain their existing lifecycle.

ARCH-ORDER: the most dangerous ordering is a deferred-question decision from an old provider completion applied to newer text. Bind classification to snapshot coordinates/bytes and existing invocation generation; no callback can mutate authoritative state outside its current owner. Existing move and inherited-owner transitions are reused, tested with pending and unconfirmed responses.

ARCH-DRY / ARCH-PURE: one pure policy and one side-root relation; structural parser and IO stay thin. ARCH-PURPOSE: explicitly sweep existing consumers and templates, not just add a new tag decoration. ARCH-MOCK: reuse stateful fake Couch/provider seams. ARCH-CONSTRAINTS: counted work above. These cover all delivered architecture principles.

## Function-level verification strategy (PQ-1)

Pinned exported fixtures remain executable oracles; tests drive the actual functions below, not a copied fixture interpreter. Each new pure function gets a direct plain-table test; integration seams use existing stateful fixtures.

| Production function | Adversarial class and mechanical guard |
|---|---|
| sync.validate_manifest / render_snapshot / read_output | Mutate versioned manifest/member and filesystem shape; assert complete preflight and byte-identical output on refusal. |
| brief.list / brief.load | Mutate name-only manifest/body records; digest and flag-absence guard rejects half-migrated input. |
| chat_structure.snapshot | Generate Markdown containers/literals and malformed delimiters; compare typed source coordinates with pinned fixtures, count traversal and parser calls. |
| chat_policy.scan / chat_policy.items | Grammar-aware seeded documents plus pinned examples; assert disjoint valid/misplaced tags, laminar sections and exact submitted-line notices; mutation controls prove branches execute. |
| collaboration_value.parse | Mutate legacy evidence beside arbitrary metadata; preserve supported chat forms and root-plain quote semantics, degrade unread evidence visibly without refusal. |
| collaboration.eligible / validate_edits | Mutate exhaustive classification identities and overlapping proposals; coverage, unique source match and protected-byte guards reject the whole batch. |
| skill_invoke.invoke | Controlled fake-provider/tool ordering; zero producers/readback/apply on preflight refusal or question-only no-op, stale and ABA source witnesses cannot complete successfully. |
| review.run_via_invoke | Stateful mixed-ask results; deferred questions produce exact notice, unchanged result produces no journal/projection, resubmit stops. |
| entity_range.section_range / entity_textobj operations | Generate neighboring heading attachments; source conservation and native delete/yank/paste/undo parity enforce tag+heading ownership. |
| question_tags / reference_candidates / outline projections | Mutate tag role and surrounding source; valid chat association cannot be stripped or opened as a file, ordinary references remain unchanged. |
| highlighter.compute_window_decorations | Scale document and viewport independently; assert no semantic parser call and unchanged existing bounded reads/paint, with review tags as ordinary text. |
| side_document_path.relation | Generate normalized path/parent graphs; actual-parent and owning-root proof rejects escapes/cycles without inference from basename. |
| attention.discover / saved | Stateful filesystem/mtime fixture; root dedup and one monthly depth bound scans, unreadable entries cannot erase attention evidence. |
| agentic_document.inherit | Stateful fake Couch with paused replies; confirmed actual-parent proof controls ownership and stale/unconfirmed responses cannot grant it. |
| document_move.plan / existing move journal | Pinned trees plus layout mutation; existing preimages/journal recover partial effects and preserve attachment/link/index data. |
| presentation.decorations / edit_round.refresh | Producer fixture and malformed wire mutations; effective stored presentation and generation guards preserve historical meaning and reject malformed known data. |

## Implementation tasks (one final review boundary)

### 1. Pin contract and migrate bundle/brief consumers together

**Files:** synchronizer above; `lua/parley/skills/review/{export.json,SKILL.md,round.md,collaboration-modes.md,review-convention.md,brief.lua,init.lua,local-adapter.md,briefs/,examples/}`; delete old generated `modes/` plus obsolete `mode.lua`/`instruction.lua` after sweeping imports. Tests: `tests/unit/review_protocol_export_test.py`, `tests/integration/review_protocol_bundle_spec.lua`, replace `review_mode_load_spec.lua` / `review_mode_spec.lua` / `review_instruction_spec.lua` with brief contracts.

- [x] Write failing sync/brief tests using the function-level strategy above. Run `python3 -m unittest discover -s tests/unit -p review_protocol_export_test.py`; expect current v4 rejection.
- [x] Materialize source members with `git show` from the exact pin, including the canonical grammar symlink target; record Git revision and member digests in test provenance. No copy from a moving working tree.
- [x] Extend pure validator to v4 while retaining prior manifest tests. Include `briefs` in owned output safety scanning, explicitly remove obsolete generated mode files, regenerate and verify zero drift. Preserve local Lua and local adapter.
- [x] Change runtime source/manifest to flagless brief bodies and current-only marker instructions. Remove review mode args, instruction context and no-marker mode bypass; local adapter text states the TL's question exception. Keep generic provider selection unchanged.
- [x] Remove retired completion from `review_send.lua`, `frontmatter_enum.lua` and obsolete attachment callbacks in `init.lua`; remove mode keys from new templates in `defaults.lua`. Sweep all remaining writers/readers and update tests, not existing operator metadata.
- [ ] Run `make test-spec SPEC=modes/review`, `make test-spec SPEC=ui/frontmatter_typeahead`, `make test-spec SPEC=notes/templates`; commit with Agent and Co-Authored-By trailers.

### 2. Build one chat snapshot and guarded local proposal

**Files:** `chat_structure.lua`, `chat_policy.lua`, `collaboration_value.lua`, `collaboration.lua`, `review/init.lua`, `skill_invoke.lua`, `tools/builtin/propose_edits.lua`. Tests: new `tests/unit/review_chat_policy_spec.lua`, `review_local_proposal_spec.lua`; existing collaboration/value, skill_invoke_review, review_send native tests.

- [x] Write failing snapshot/policy/legacy tests from the function-level strategy and pinned executable oracles. Expected after files describe Couch IO, not local file creation.
- [x] Extract typed Markdown structure once; implement pure ChatScan, innermost/item extents and exact legacy notice projection. Retain established bounded legacy parser, converting failures to visible policy notices. Stop for TL if reference semantics demand general YAML expansion.
- [x] Require exhaustive review_asks classifications on the single review proposal. Validate marker identities and protect questions, operator chat-item text, tag+heading and metadata before the existing write tool. Extend validate_edits hook with full input, not another dispatcher. All-question no-op bypasses disk writes/backups and reports the exact limitation notice.
- [x] Implement the stateful proposal/admission verification strategy; rejected preflight preserves source and starts no effects.
- [x] Exercise controlled invocation event sequences against the existing lifetime owner; assert deferred questions cannot cause automatic repeat.
- [ ] Count work at N/2N and mutate tag detection, question protection and classification coverage guards: each appropriate test must fail. Run mapped review and skill-system tests on each runtime; commit.

### 3. Preserve heading attachment and ordinary tag text

**Files:** `entity_range.lua`, `entity_textobj.lua`, `document/lexical.lua`, `question_tags.lua`, `reference_candidates.lua`, `outline.lua`, `highlighter.lua`, highlight registration/config as required. Tests: entity range/textobj/delete parity, question tags, references, outline parity, highlighter document/visible spans.

- [x] Write failing attachment/projection/native tests using the named function strategies; retain the old editing-dialect contract.
- [x] Derive tag association from the shared snapshot/structure; adjust selected section start and prior section end consistently. Inner text objects keep the heading/tag. Update generic tag/ref/outline consumers to avoid stripping or opening `chat` as a file for valid review tags; ordinary labels/file tags remain unchanged.
- [x] Leave standalone review tags as ordinary source text in the current bounded markdown/chat renderer. Add no semantic render parse, highlight group, conceal, badge or typeahead. Ordinary non-review tags retain styling.
- [x] Verify native operation parity/source conservation and counted viewport reads, proving no render-time policy parse.
- [ ] Run `make test-spec SPEC=chat/entity_delete`, `SPEC=context/file_references`, `SPEC=ui/outline`, `SPEC=ui/highlights` sequentially on each runtime. Commit.

### 4. Make monthly side-document readers and ownership agree

**Files:** `side_document_path.lua`, `attention.lua`, `agentic_document.lua`, `side_tree_model.lua` only if needed; existing mover files only if reference tests expose a gap. Tests: new pure side-path spec; attention finder, side inheritance, side tree, document_move_plan and existing move integration specs.

- [x] Write failing path/discovery/inheritance tests from the generated-graph and stateful-fake strategies above.
- [x] Add pure owning-root/actual-parent relation and use it in attention discovery/save detection and inheritance. Deduplicate roots, scan one monthly level, map attachment to actual parent rather than top root. No parent proof is inferred from pathname membership alone.
- [x] Reuse existing navigation and recursive move journal; add month/grandchild variants to exported move-orphan/move-rename qualification. Assert backlinks, relative links, discussions index and unknown metadata remain intact, and old flat/qa follow-up links stay unchanged.
- [ ] Use filesystem-backed fake Couch through production request/inherit owner; retry and uncertain outcomes remain existing model transitions. Run mapped `ui/attention_finder`, `modes/session_sync`, `ui/breadcrumb`, and relevant move tests sequentially on both runtimes; commit.

### 5. Keep historical round display compatible; acceptance and close

**Files:** `presentation.lua`, `edit_round.lua`; tests `presentation_spec.lua`, `skill_render_round_spec.lua`, `edit_round_spec.lua`, fake Couch round fixtures. Docs: `atlas/modes/review.md`, relevant linked atlas pages, README/TOOLING and `atlas/traceability.yaml` (verify exact existing page paths before edit).

- [x] Pin #823's landed fixture and implement the historical projection/refresh strategy above; current document keys never reinterpret stored presentation.
- [x] Add strict known-field/type controls at the read boundary while retaining opaque members. Avoid any serialization unless existing feature requires it; if it does, add independent raw unknown-value round-trip controls.
- [ ] Update atlas/help to current policy and explicit local question limitation, monthly links and legacy notices. Map every new test to the owning executable spec; run those actual mapped commands and architecture guards.
- [ ] Verify both supported runtime binaries using the harness's `PARLEY_TEST_NVIM` selector and mapped commands. Record failures individually; do not rerun unrelated full suites to hide them.
- [ ] Commit/push candidate with `sdlc pr`, run `sdlc local-check run --name suite` on pushed head. Ask hub for stage/live approval only after candidate is concrete. Do not touch :0 beforehand.
- [ ] Live steps: (1) valid/misplaced tag displays and heading move/undo keep attachment; (2) inside Couch question becomes monthly linked side doc and follow-up/side-child navigation retains owner; (3) outside Couch mixed question/command applies only command and visibly leaves question. Include legacy document + history rendering control. Hub owns operator acceptance.
- [ ] `sdlc close --issue 419 --verified '<returned evidence>'` owns fresh review, atlas/project gates and measured actuals. Do not adopt known-overlapping claim time without checking attribution (#580); ask hub if it still includes #418/#322. No typed hours.
- [ ] Fix blocking findings, fresh check on changed code, then `sdlc merge --yes`; preserve authoritative integrated-head suite result. Clear stage after landing and report one outcome to hub with Git-returned hash/PR.

## Approval record

The scope allocation, structural parser seam and optional review_asks envelope were approved by TL ad007bf0 before implementation. This envelope is the smallest deterministic way found to distinguish an intentionally deferred question from a missing/truncated tool answer while retaining the existing write owner; a prompt-only instruction cannot produce a reliable visible outcome or protect an identified question from the returned edit batch.

Covered: supported tag/legacy structure, existing consumer sweep, local deferral, imported v4 agent guidance, side-doc readers/inheritance/moves, historical rounds, controlled stale completion and counted growth. Not covered: a local multi-document writer or external command executor (explicit TL exclusion), changes to Pair's unlanded parser/projection API, or a general YAML implementation (no expansion without replanning).


## Revisions

### 2026-10-23 17:35 — plan-quality PQ-1 / PQ-2

PQ-1: compressed prose test-case inventories into named production functions with one adversarial/mechanical strategy each. Imported fixtures remain executable oracles. PQ-2: replaced the unbounded render-time assumption with the TL-approved 64 KiB/2,048-line optional tint envelope, p95 <10 ms qualification and visible oversized degradation; explicit guarded local actions keep the existing 1 MiB limit. TL approval 862a7213 cites the real workload. No incremental parser, persistent cache, watcher or new writer added. Proposal preflight now explicitly precedes every producer, and no-op/refused completion bypasses readback/apply; classification uses existing zero-based marker coordinates.


### 2026-10-23 17:54 — omit tint (TL b8c4f2df)

Tint is outside #419 now. Preserve recognition, tag/heading ownership/protection, and ordinary source rendering. No render-time native parser, tint group, admission notice or tint-latency gate remains. #434 is the unclaimed operator-demand follow-up with all measured failures (58.462ms original renderp95;64headingprofile22.323ms render/15.415ms snapshot). The native node getter was already a byte-span slice; no speculative optimization is carried. Keep explicit-action snapshot bounds and source coordinates, and test the absence of added render parsing.

Legacy map matching is explicitly ASCII-only by TL 2a6920bd. Non-ASCII map names emit the exact migration notice rather than matching/guessing. This is a documented operator-approved exception to the broader Go normalization, not a new native Unicode seam; tags on Unicode headings remain supported.


### 2026-10-23 18:15 — bind admission to the existing write preimage

Fresh review exposed that a valid buffer proof did not bind the async tool's later disk read. Keep the existing producer/profile/write owner: capture private expected source bytes, compare its actual read before transform/backup, and retain its revision CAS for read-to-write changes. Guarded failed tools preserve the buffer without reload or a journal. Local byte proof supports UTF-8 Unix text; a differing encoded representation refuses visibly rather than applying normalized offsets to different bytes. No second IO owner, watcher or state machine. Closed unreadable leading headers still protect their original bytes independently of whether legacy metadata can be interpreted. Eligibility uses one merged literal interval index and logarithmic overlap lookup; unchanged historical marker parsing is not claimed globally linear.


### 2026-10-23 18:17 — shared closed-header rule prerequisite (TL05fc963f)

Ignore tag/heading declarations inside every closed leading header, retaining the unread-header notice and body-command admission. This must agree with Couch, rather than ship as a Parley-only exception: ariadne#581 owns the shared reader/fixture update. Keep the #576 bundle pin until #581 lands, then pin the new case and any manifest change before final qualification. Existing synthetic regressions may implement the approved rule, but no unlanded runtime/fixtures are consumed.


### 2026-10-23 18:23 — qualification checkpoint and actual exception

All runtime implementation is committed through f6e32d3f, with the #581 fixture pin still pending. Root final focus passed165 tests (async20, references62, invocation70, presentation13) on0.12.5; core/fixtures60, native lookup-refusal12 and monthly real-move6 pass each supported runtime. Earlier notice migration87, historical projection29 and byte/codec controls remain separately recorded. Whole-tree lint:866files,0warnings/errors. Preserve the original native entity-file200s qualification timeout; the focused new refusal cases passed separately, and the full recorded suite must still verify the original native spec.

TL59404f19 authorizes precise --no-actual at close:9.24h preview includes a357-minute11:18–17:15 segment for #418/#322 before #419 implementation (ariadne#580 concurrent claims). Cite it in --verified; no typed hours. No full suite, close, stage/live acceptance or merge has run. Exact next step: obtain landed ariadne#581, repin its exported rule/fixtures, qualify the pin, push the candidate and run its one recorded suite; then stage only with fresh hub approval and complete joint acceptance.
