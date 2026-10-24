---
id: 000419
status: working
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-23
estimate_hours: 4.77
collaboration-mode: collaboration
card_mirror: 'a68015d9c2c21712da05eeb95e6fd56f496bb351' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T11:08:07-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: operator}
---

# unified-editorial-interface: typeahead for the mode keys and heading comments; conceal comments as badges

## Problem

## Spec

**Active contract, 2026-10-23:** one collaborative behavior, `@@chat@@` sections, and highlight for new edits. The operator pivot and TL allocation supersede the historical three-axis interface below. Source contract and exported fixtures are pinned to landed ariadne#581, Git `5a17f789619d3dcaafec62ae51b350833836a3e7` (PR423). Preserve legacy metadata; create no mode keys or standing instruction. Remove existing mode/selector completion as well as omitting new typeahead.

Share one snapshot-derived chat projection between admission/protection, tag recognition and heading attachment. A standalone tag directly above a parsed ATX heading, outside code, is chat; boundaries, legacy scalar/maps/comments, nested item grammar and exact notices follow the pinned source. Malformed or retired mode metadata emits notices and never refuses an otherwise valid Couch round. For local review, an explicitly declared legacy collaboration map that cannot be read refuses source mutation visibly with use-Couch recovery, because its protection cannot be proven (TL b34bb4e7); no-declaration unread headers retain body-command handling. Legacy map entry matching is explicitly ASCII-only (TL 2a6920bd); a non-ASCII name is unmatched with `legacy chat map entry not matched; use @@chat@@`, never guessed. Tagged Unicode headings remain supported. Keep `@@chat@@` visible as ordinary text, with no tint or conceal (TL b8c4f2df); ordinary tags and references retain their behavior.

**Local adapter boundary (authenticated TL 3d546ddc):** outside Couch, retain the existing single-buffer write owner. Commands apply in place. Question/unclear/unsure asks remain byte-identical and produce the visible notice `questions are answered in a side doc by Couch review; left unchanged`. Never answer a question in place or allocate a local side doc. Couch's agent review owns multi-document questions, chat answers, follow-ups, folds and index writes. This is an explicit supported limitation, not a deferred second writer.

Import export v4 and its flagless briefs atomically with consumers. Side-document readers, owner inheritance, attention, navigation and the existing recursive move owner accept monthly and legacy flat layouts, actual-parent links and same-root grandchildren. No Lua side-doc allocator exists today; the imported agent instructions own the creation naming rule. Keep question/command classification in the agent, not a punctuation heuristic.

**Historical wire compatibility (pair:3, 47e8cb67):** new Couch writes are highlight at round and span level; stored legacy per-span presentation retains its meaning, falling back to round presentation then highlight. Never let current document keys reinterpret old round data. Pin landed #823 compatibility fixtures separately from the v4 policy oracle; consume no unlanded #838 runtime or proposed Read.Editorial API.

<details>
<summary>Superseded original specification — historical evidence, not the active contract</summary>

**Settled with the operator (10-22, design chat in brain `session.side/2026-10/2026-10-22-01-editorial-modes.md`):**
- **Uniform names:** `collaboration-mode` (where an answer goes: discussion / collaboration / chat),
  `presentation-mode` (how edits are shown: highlight / direct / propose), `processing-mode` (how an edit is made:
  the review modes in `ariadne/construct/local/universal-review/modes/`: copy-editing, developmental, fact-check,
  free-form, line-editing, proofreading; unique prefixes allowed). The old keys `presentation` and
  `process-instruction` stay readable as aliases. `process-instruction`'s free text splits out into
  `processing-instruction`.
- **Per section:** all three can be set for one section by an HTML comment directly under its heading:
  `<!-- collaboration-mode: chat; processing-mode: copy-editing -->`. Couch protects that line as operator-owned;
  parley conceals it as a badge.
- **Frontmatter:** each key is one value covering the whole document; the per-section map form
  (`collaboration-mode: {chat: ["Operator instructions"]}`) is retired.
- **Precedence:** section comment, then document frontmatter, then the built-in default.
- **Typeahead (required):** on a line next to a heading, `<!-- ` offers the three keys, `key: ` offers that key's
  values, `; ` offers the keys not yet used, and accepting the first key inserts the closing ` -->`. Values come from
  the modules that enforce them (extending parley's `lua/parley/frontmatter_enum.lua`), never a second list.


Project `unified-editorial-interface`; follows the spec in ariadne (dependency). In parley:
- **Typeahead** for the new frontmatter keys and their values (key-name completion, `presentation-mode` and
  `processing-mode` values, `processing-instruction` free), extending `lua/parley/frontmatter_enum.lua`, with values
  drawn from the enforcing modules.
- **Heading-comment typeahead:** the `<!-- ` / `key: ` / `; ` flow on a line next to a heading, auto-inserting
  ` -->` on the first accepted key; works with nvim-cmp and with Vim's popup, as today.
- **Conceal** the heading comment as a small badge next to the heading (showing the effective overrides), revealed for
  editing when the cursor is on the line.


**Side-doc layout (decided 10-22):** `<doc>.side/YYYY-MM/YYYY-MM-DD-NN-slug.md`: a year-month subfolder, with the full date kept in the filename so a file still makes sense when linked, grepped or moved. **No migration:** existing flat names stay valid (readers accept both). Reason: `ops/session.side/` already holds about 270 entries, 261 from October alone. For this issue: make this repo's side-doc creator use the new layout and its readers accept both. Applies to the naming rule in the universal-review spec (`collaboration-modes.md` §4) and to every side-doc creator (parley, Couch, and tl-lead's side-doc helpers).


**Scope addition (TL, 10-23):** #419 also owns parley's **round-consumer upgrade for mixed per-section presentation**:
pair#823 adds an optional per-span presentation field to the `.round` JSON (for sections that differ, e.g. direct in
one and highlight in another), with the document-level value kept as the fallback for old packets. #419 renders
those spans; parley.nvim#418 covers only the whole-document canonical/legacy resolution. pair:9 shares the exact
additive span contract.

</details>

## Done when

- The pinned v4 export, five flagless briefs and exported reference fixtures are packaged and verified; the old mode/standing-instruction pipeline and completion are retired. New templates write no mode keys. Existing metadata remains untouched.
- The production chat projection matches pinned tag/legacy contexts and exact notices, including empty collaboration-mode and a leading thematic break. The TL-approved ASCII legacy-map bound emits the exact migration notice for non-ASCII names. Duplicate normalized headings all match; nesting, code and literal exclusions are covered.
- A valid tag remains visible as ordinary text without tint or conceal and moves with its heading through native section operations. Moving/deleting the preceding section does not take it; ordinary tags/references and the established editing-heading dialect stay compatible.
- Outside Couch, commands apply through the existing write owner; questions remain unchanged with the exact limitation notice above. Mixed question/command batches preserve questions, and missing/malformed classification cannot cause a write. No local side docs are created.
- Monthly side docs, actual parents, same-root grandchildren, old flat files and existing linked qa files retain correct navigation/ownership and attention. Recursive document moves preserve links, backlinks and index entries using the existing transaction owner.
- New round edits highlight; stored mixed/legacy rounds retain per-span > round > highlight fallback with strict validation and unknown-field preservation where rewritten.
- Both supported Neovim runtimes pass mapped unit/native/conformance tests, counted N/2N policy-growth controls and a fresh recorded suite. Hub-arranged live acceptance verifies tag display/moves, Couch question-to-link behavior and monthly link navigation. The local question limitation is verified by the supported-runtime tests; the operator retry is blocked by the pre-existing forced-tool HTTP400 tracked separately as #441 and explicitly excluded from #419 by TL b532446a.

<details>
<summary>Superseded original acceptance — historical evidence</summary>

- Typing `<!-- ` under a heading offers the three keys; `key: ` offers its values; `; ` offers only unused keys; the
  closing ` -->` is inserted (tests on both nvim versions).
- Frontmatter key and value completion covers all three keys (test).
- The comment renders as a badge and reveals on the cursor line (test).

</details>

## Plan

- [x] Approve the durable plan in `workshop/plans/000419-collaborative-chat-interface-plan.md` with the hub.
- [x] Implement pinned policy/bundle, single-buffer admission, tag/heading ownership, side-doc readers and historical round compatibility using existing effect owners.
- [x] Verify both runtimes on the recorded suite and obtain inside-Couch live acceptance; TL b532446a accepts the local tests and allocates the pre-existing standalone failure to #441.

Next workflow gates: close review, then landing; hub owns live checkout fast-forward.

## Log

### 2026-10-22


### 2026-10-23 — implementation gate and first verified slices

Plan-quality accepted PQ-1/PQ-2; estimate-quality INFO accepted the calibrated 4.77 h derivation (advisory: feature sizes differ; include qualification inside each feature allocation). change-code completed successfully on this branch. No actual adopted.

Root proposal/core driver RED: seven missing-guard assertions and three driver failures (refusal bumped changedtick, question-only failed, missing proposal succeeded), zero test errors. GREEN: 69 driver +7 pure proposal cases, both targeted harness census phases clean, exit0 on current runtime. Guarded calls now preflight before any producer; refusal and validated no-op bypass source readback/apply. New pure local_proposal owns classification identity/coverage and protected-byte validation; existing skill_invoke/tool write owner remains authoritative. Routing/UI integration and compatibility runtime qualification remain outstanding.

Parallel bundle slice reports Python28 and brief8 green with pinned v4; monthly reader slice reports101 focused green. Those reports are provisional until root integration verification. Top-level missing-module RED tests exposed a Plenary hang; owned foreground runs were interrupted, wrapper census ended clean, and tests now use assertion-based missing-module failure. No live fleet process was signalled and no full suite has started.

## Revisions

### 2026-10-23 11:15 — operator pivot to collaborative review and @@chat@@

Authenticated TL 790dfd6d supersedes the prior three-axis keys, heading comments/badges and all mode typeahead in Spec/Done-when above. One collaborative behavior is the default; @@chat@@ immediately above a heading marks a chat carve-out. No mode keys or standing processing-instruction are created. Old chat declarations stay readable through the spec's mapping; retired choices are ignored with a short notice. Existing metadata is preserved. ariadne#575 owns the exact grammar and exported reference fixtures; pair#838 owns Couch enforcement. **Do not write #419 runtime code before #575's fixtures land.**

**Proposed active Done-when:** recognize @@chat@@ only in the approved contexts, attach it to its heading through existing heading/section move operations, and render a light highlight without hiding the editable source. Default collaborative questions produce linked side documents and commands stay in place according to the shared fixtures; discussion links/index and new month-based side paths preserve the owning root, parent and old flat links. Legacy chat mapping and ignored-key notice match the pinned fixtures. No new mode completion or automatic mode-key fill exists. Both supported Neovim runtimes pass the reference cases plus native rendering/move/link tests; an operator live check verifies tag display/heading moves and question-versus-command behavior.

**Proposed plan to TL:** after #418 resolves, start a separate main-based #419 branch; pin the landed #575 v4 manifest/fixture revision and consume flagless brief members through the build-time sync and local review adapter. Keep policy parsing pure and shared between routing, protection and decoration; existing buffer/render/section-move/side-doc ownership applies effects. Extend the existing side-document path/link primitives rather than adding another creator. Add mutation controls for real parser/routing/move/link paths so copied fixtures cannot pass as inert files. Enumerate tag contexts, fence/literal exclusions, heading nesting/duplicates and move boundaries from the producer's fixtures before coding. Measure scan operations at N and 2N, with no full-document rescan per heading.

The former pair#823 per-span presentation assignment must be reconciled with the new always-highlight policy, not silently implemented as obsolete selectable modes. Preserve old round/review-record/resume data and unknown fields; coordinate pair#838's actual legacy wire expectations before choosing consumer behavior. Keep the landed pair#823 fixture available as backwards-compatibility evidence, not the pivot's policy oracle.

**Confirmed compatibility:** current sync-review-protocol.py accepts versions 1/2/3 and refuses v4 before output IO. Runtime reads the packaged snapshot, never ariadne's live checkout; existing installs keep working on v3 until #419 updates the consumer and bundle together. Manually copying v4 files over an old bundle is not guarded at runtime and is not a supported upgrade path. Producer ariadne:2 was told this boundary and asked for the exact member shape and tag/legacy-map fixtures.

**Ownership decision requested:** outside-Couch plain-file submission on main still prompts for/writes process-instruction. With #418 narrowed to the legacy reader, #322 cannot remain an acceptance-only close against #418. TL must assign that mode-free submit adapter/visible outcome either to #322 or explicitly to #419; no work on that slice is assumed here.

### 2026-10-23 — rescope reserved; awaiting contract and scope approval

Claimed #419 for this slot; status remains open until start-plan. No stacking on the unlanded #418 branch and no pivot runtime edits. Proposal and revisions are being published independently of #418's code. Exact next step: hub approves allocation and #418 resolution; then start-plan #419 from main and complete its durable implementation plan against landed ariadne#575 fixtures. The previous TTY capture was unavailable on recovery; branch, issue Log and authenticated Couch receipts are the evidence.


### 2026-10-23 17:35 — landed v4 prerequisite; active scope and local boundary

ariadne#576's revision above was verified with Git. Authenticated correction 1760fe44 supersedes the earlier peer statement that notices did not change: empty collaboration-mode reports `collaboration-mode is empty or malformed; ignored`; unread-frontmatter reports only a closed leading fence block, not a thematic-break opener. Read code and examples at the pin, not a prior snapshot.

#418 and #322 are landed; start-plan created this separate main-based branch, changed the card to working and pushed it. Catch-up rebuilt substrate tools. Generated issue vocabulary changes from weave were saved to Git-local `sdlc/diagnostics/419-weave-refresh.patch` and restored before the successful start-plan; unrelated generated configuration is not included in this issue.

TL 3d546ddc explicitly keeps local review single-buffer: leave questions unchanged with a visible Couch-side-doc notice; commands still apply. The active Spec and Done-when now state this exception. Pair #838 is owned by pair:3 and remains unlanded; its current plan preserves historical round/span presentation, with new writes always highlight. No unlanded branch/API is consumed.

Inventory corrected two earlier assumptions: Parley has no executable side-doc allocator to reuse, and its packaged export is v2, not v3 as the 11:15 compatibility note said. The v4 sync/consumer upgrade is atomic; current packaged runtime does not read live Ariadne. Existing generic tags, section ranges, attention discovery and side ownership all need explicit reconciliation, listed in the durable plan. No runtime code or tests changed during planning.


### 2026-10-23 17:35 — approved plan; first plan-quality findings

Authenticated TL ad007bf0 approved the parser/proposal seams and joint operator acceptance with pair#838 at the end. First change-code review returned PQ-1 (named function test strategies) and PQ-2 (render parse envelope), both Important. No runtime code written. Verified current highlighter caps rows/bytes but does not bound a new whole-document parser; accepted the finding. TL 862a7213 approved optional tint only through 64 KiB AND 2,048 lines, p95 under 10 ms on both runtimes; larger docs stay editable/submittable with no tint and a short notice. Explicit guarded local actions retain 1 MiB admission and visible refusal above. Durable plan records the refinement and function-level verification strategies. Exact next step: rerun change-code, then derive the estimate only after plan-quality accepts.


## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only. Calibration is reported stale by sdlc, so this is provisional ship-time, not a claim about operator attention.

Five focused Lua/Neovim primitives: chat structure/policy, guarded local proposal, tag/heading UI, side-document readers/inheritance, and historical round display. Each uses the table midpoint (design 2.0 h, implementation 1.0 h); thorough-spec discount makes design 0.4 h and v3.1 makes implementation 0.4 h. Existing bundled Markdown parser halves only the structure primitive's design to 0.2 h (library-availability check). Familiar stack multiplier 1.0. Bundle migration is a cross-cutting refactor (design midpoint 0.6 ×0.2, implementation midpoint 0.35 ×0.4); docs and one review use their table midpoints similarly. One parser/provider API conformance discovery allowance uses implementation midpoint 0.45 ×0.4. No second writer, new service or speculative general YAML budget. Thorough-plan design buffer 15%.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.20 impl=0.40
item: lua-neovim design=0.40 impl=0.40
item: lua-neovim design=0.40 impl=0.40
item: lua-neovim design=0.40 impl=0.40
item: lua-neovim design=0.40 impl=0.40
item: cross-cutting-refactor design=0.12 impl=0.14
item: atlas-docs design=0.025 impl=0.05
item: milestone-review design=0.02 impl=0.14
item: real-api-discovery design=0 impl=0.18
design-buffer: 0.15
total: 4.77
```

Design subtotal 1.965 ×1.15 + implementation subtotal 2.51 = 4.76975 h, rounded to 4.77 h. No cross-repo vendor overhead: only Parley's code changes; landed source pins supply contracts. This forecasts the approved scope, without adopting the earlier overlapping claim window as an actual.


### 2026-10-23 17:48 — explicit legacy-map name envelope

TL 2a6920bd declined a Unicode normalization seam: the real legacy names are ASCII and migration uses tags. Bound legacy-map name matching to ASCII; non-ASCII entries are unmatched with one exact `legacy chat map entry not matched; use @@chat@@` notice, rather than a guess. Tag recognition still accepts Unicode headings. Production policy and regression tests record this intentional source-oracle exception. No new Unicode utility or parser surface.


### 2026-10-23 17:54 — optional tint removed after measured qualification

TL b8c4f2df removed tint from #419. Keep tags recognized, attached to headings and protected, rendered as ordinary text. Record failed Neovim0.12.5 qualification: 50-sample512heading/2048line/30KiB fixture p95render58.462ms; laterprofile render51.377ms/snapshot38.690ms/policy2.178ms. The smaller64heading/2048line/39KiB fixture still yielded render22.323ms/snapshot15.415ms/policy0.497ms, existingviewport9.183ms. 0.11.7 latency was not qualified before the removal. get_node_text was already a direct byte-span source:sub; the copying hypothesis was disproven and cosmetic rewrite reverted. No further parser optimization or cache is introduced for optional decoration.

Filed #434 unclaimed (`optional @@chat@@ tint within a render budget`) with these measurements and operator-demand prerequisite. Active Spec/Done-when/plan now require ordinary text and no render-time policy parse; earlier tint envelopes remain historical. The rest of #419 continues, with joint operator acceptance alongside pair#838 at the end.


### 2026-10-23 18:15 — implementation checkpoints and adversarial integration

Imported the exact v4 bundle and five flagless briefs in 20ae1789; monthly side-path readers and historical stored presentation are checkpointed in bf327a83. Focused notice/submit migration passes 87 cases on each of Neovim0.12.5 and0.11.7, including12 native attached-UI cases; full notices remain exact in :messages while bounded captions permit the next typed key. Routing/source projection controls pass11 cases; heading/item newline regression first reproduced tag detachment and then passed with the protected boundary fix.

Fresh review identified a buffer-to-disk preimage gap: an external disk edit could move an otherwise permitted old_string into an operator-owned item without changing the buffer witness. A held-provider regression reproduced a successful forbidden write. The existing async write owner now checks private invocation bytes before any backup/write, retaining the existing revision CAS afterward. The regression plus driver70 and async19 cases pass on both runtimes, with unchanged buffer tick and no backup on refusal. Additional forged-input proof control and parser closed-header/growth verification are pending. Byte-different/non-UTF8-Unix local representations refuse visibly; no normalization can bypass the byte proof. Full suite, final close review and joint operator acceptance have not run.

Recovery gap: previous terminal capture is unavailable (couch --peek returned source none); current branch, committed plan, issue Log, authenticated messages and returned test results supply continuity. Next: finish closed-header/eligibility checks, update traceability, commit/push the remaining changes, then run the recorded full suite on the candidate head. No tint work remains; #434's filing report is submitted to the hub.


### 2026-10-23 18:17 — shared closed-header edge and remaining qualification

TL05fc963f approved ignoring tag/heading declarations inside any closed leading header while retaining unread-header notices and admitting body commands, with a shared prerequisite: ariadne#581 must land the same behavior and fixture. ariadne:2 acknowledged that it will send the merge revision/case paths; keep #576's pin until then. No unlanded files are consumed. Final source qualification/landing waits for that pin; unrelated implementation checks continue.

Core52 focused tests passed both runtimes, including closed unreadable-header byte preservation and actual local admission. New literal eligibility improved from3.94x to2.18x VM instructions at64/128 input. The untouched parse_markers path still measures3.481041x; filed unclaimed #435 with discovery evidence and an explicit normal-harness regression prerequisite. No global linear claim. Documentation/static/export checks33 and production-mapped typeahead18 pass. Most feature slices are committed; reference unknown-lookup/native refusal and month/grandchild move qualification remain active. One native whole-spec qualification hit its200s deadline before the new refusal cases; preserve that unresolved verification limit, isolate the new cases, and let the final suite verify the existing native spec normally.


### 2026-10-23 18:23 — committed candidate; awaiting shared fixture pin

Current implementation checkpoint f6e32d3f includes visible ordinary tags, attached/protected heading ownership, typed lookup failures and native refusal; root reference-selection control proves one shared projection. Root final focus165 passed on0.12.5 (async20, reference62, invocation70, presentation13); core/pinned-before fixtures60, focused native refusal12 and monthly real-move6 each pass both0.12.5 and0.11.7. Whole-tree lint866files reports0warnings/0errors and diff checks are clean. The existing large native entity regression hit its200s qualification deadline in one targeted run; new native cases were isolated and passed, but the final suite still must verify that existing file. This is not a full-suite pass.

Actual preview at codepin0a1283df:9.24h, window11:08:07–18:21:44, including357.3minutes11:18–17:15 for #418/#322. TL59404f19 approves close --no-actual with --verified citing that contaminated concurrent-claim attribution (ariadne#580), no typed hours. No actual adopted.

Remaining prerequisite: landed ariadne#581 and its new closed-header fixture/manifest pin; ariadne:2 will send it. Current bundle remains exactly #576. After repin: focused qualification, push candidate, one recorded suite, fresh hub-approved stage/joint operator check, close review and merge. No stage or merge action is authorized by old #322 approval; no :0 files touched. Follow-ups #434 and #435 are unclaimed and reported to hub with submitted receipts.


### 2026-10-23 19:27 — new pre-close selector exercised on pushed draft

Authenticated fleet notice c64d51ab adopts ariadne#578's command. Ran sdlc local-check run --pre-close on pushed d64283a04d4a4224aed8866d676c13c5edd59787. It correctly selected suite because trains are off and main declares no affected graph, refreshed the verified private sibling suite helper, and retained normal FIFO queue position. Run lease-1002561823; log .git/sdlc/test-stats/inflight/42b7c10950aed39224f3491f2dda07dd/run.log in the common Git directory. No result yet; keep this runner, do not duplicate it.

ariadne:2 confirms #581 only just entered planning; keep #576's pin. Its eventual contract also validates answer destinations (nonempty, no whitespace or parentheses). Wait for landed fixtures before repinning/qualifying that rule. This current suite is early qualification requested by the fleet notice, not final evidence for a future changed pin.


### 2026-10-23 — pre-close completed red; own corrections qualified

Attempt42b7c10950aed39224f3491f2dda07dd on d64283a04d4a4224aed8866d676c13c5edd59787 completed as unattributable-failure, exit2,4m11s after620s queue. Saved raw log: common Git directory sdlc/test-stats/failed/42b7c10950aed39224f3491f2dda07dd.log (printed SHA256 prefix5c05f21e90cd). Exact failed files: tests/arch/buffer_mutation_spec.lua, tests/integration/new_chat_spec.lua, tests/integration/editor_endpoint_registry_spec.lua. Compatibility was not reached. The original entity_textobj native spec PASSED in30s; its earlier targeted200s deadline is no longer an unresolved branch regression. The new refusal, fixture, move, local review, and session-sync native specs also passed in this run.

Two own corrections: move the buffer-only snapshot adapter from question_tags into its sole IO caller outline, preserving the purity guard; replace the remaining new-root/child template assertions with absence of all retired keys. A complete mode-key test sweep retained intentional legacy reader fixtures. Focused arch10/new-chat11/outline-parity16/outline22/tag-consumer9 =68 pass on EACH runtime, with clean census/sentinel; changed-file lint0warnings/errors and diffcheckclean. No architecture guard was weakened.

TL53c759dd identifies the endpoint after_each pending-drain timeout at line70 as the case already registered under #430, being fixed in #421 (stale cached libuv clock under disk load). All10 endpoint assertions passed; no new sibling filed, no endpoint production edits. This supersedes the earlier unclassified hypothesis, not the saved raw result. The next full run waits for #581; #421 is expected to land around then. Do not blindly retry this failed head. After the landed pins/fixes, update the branch and use sdlc local-check run --pre-close again.


### 2026-10-23 20:33 — shared #581 pin qualified

Authenticated ariadne:2 receipt75ee0810 and TL78192242 confirm ariadne#581 / PR423 landed at5a17f789619d3dcaafec62ae51b350833836a3e7. Verified the Git object and ancestry in the primary ariadne clone; the private sibling lacks that object, so no files were imported from an unlanded branch. Generated export remainsv4,84members/75fixture files/17cases; all85generated files including the manifest were byte-verified against the landed tree. Pinned hash test first failed on the old export, then Python28 and Lua wrapper1 passed.

The new chat-answer-invalid before-fixture reproduced the old reader accepting an invalid destination. Updated only the pure answer-target predicate to match shared ValidAnswerTarget: nonempty, no parentheses or any Go Unicode White_Space character, with valid Unicode filenames preserved. The new frontmatter-unread-tag fixture confirms the existing closed-header rule and actual guarded body-command output, including byte-identical header preservation. Fixture10+policy13 pass on EACH Neovim0.12.5 and0.11.7 with clean sentinel/census. Exact unread notice retained. Whole-tree lint:866files,0warnings/errors; git diff --check clean. No side-document allocator or new effect owner.

Next: commit/push the pin and checks; wait for parley.nvim#421 to LAND before the next recorded pre-close run (TL78192242). No stacking, no retry on obsolete bytes, no close/stage/live acceptance/merge yet. The previous suite's endpoint teardown is the #430 case fixed by #421 per TL53c759dd; the earlier unclassified plan note is superseded by that disposition. Actual exception remains --no-actual for ariadne#580's contaminated concurrent-claim window.


### 2026-10-23 21:43 — landed deadline fix integrated; fresh pre-close

Authenticated TL7c3a15c5 confirms parley.nvim#421 / PR346 landed and directs the fresh pre-close run, followed by joint acceptance with pair#838. GitHub reports merge0620eaedf13f2c73853010c1a64a6175d7c60515; verified it is an ancestor of fetched origin/main d1bb4ba89c0466ae17c02520afdbbfd705ff0537. Integrated that landed main with no conflicts, preserving the qualified #581 pin. No unlanded branch consumed. Push this checkpoint, then run sdlc local-check run --pre-close on its exact head and retain that runner; do not stage or close before its result and the joint live check.


### 2026-10-23 22:03 — fresh recorded suite passed; joint acceptance pending

The retained pre-close run lease-1700210998 / attempt1059bfecbbef70a9a1abb81ab05f3333 PASSED on pushed54e8cbe5037a0244dcf761693564c6f330b8bca9, exit0 in6m13s after714s queue. Both Neovim0.12.5 and0.11.7 completed all phases;1038PASS spec-file lines, no failure lines,4clean process censuses. Lint868files,0warnings/errors. The prior failing purity/template/endpoint files pass on both runtimes. Saved log: common Git directory sdlc/local-checks/54e8cbe5037a0244dcf761693564c6f330b8bca9/suite.log, SHA256baaadd3c635c7e7021f02c02f77f17da9598b31691e7c15a932d951ce98c6596. Status recorded as sdlc-local/suite. No code changes or newer-main chasing after this pass.

TL46f01dc5 approves sdlc stage --build on parley.nvim:0 and the docs-only correction of the active Spec's stale #576 pin to #581. Stage this checkpoint; joint operator acceptance waits for pair#838's stage and will be scheduled by the hub. Do not close or merge before the live result. Preserve the --no-actual exception for contaminated #418/#322 claim attribution under ariadne#580.


### 2026-10-24 10:47 — live outcome and standalone failure classified

Stage remainsa4cebca03e3c4fab4fe763f943f007d1b16eddd6 on parley.nvim:0. TL ee5f49e0 relays operator inside-Couch PASS for tags, side docs and answer links ("works really well inside couch!"). Outside-Couch mixed question/command produced the generic unchanged/transport-error captions. Read the exact screenshot and local diagnostic records without changing the stage or credentials. Both10:40:15/10:40:24 proxy requests reached upstream and returned HTTP400 invalid_request_error: `tool_choice: type "tool" and "any" are not supported for this model.` Captured model claude-sonnet-5-5, tool_choice type=tool/name=propose_edits, no thinking member; this construction is unchanged from main. The driver's transport error callback precedes its response validator, so #419's question-deferral code did not run.

TL b532446a accepts that pre-existing failure separately and directs #419 close/merge on inside-Couch PASS plus the recorded both-runtime suite. Filed #441 UNCLAIMED with the sanitized request/error, both exact proxy log paths, auto tool-choice direction preserving mandatory proposal validation, and actionable upstream-error caption requirement. No fix is included in #419. This revises only acceptance attribution; local behavior remains guarded and covered by the tests. Hub owns the live checkout's fast-forward after landing.

Actual policy: TL8f67dd47 revoked the former resting-branch refusal exception after ariadne#591; measure normally, no typed hours. Only a returned #593 snapshot refusal qualifies for its separate evidence-based --no-actual authorization. Earlier plan/log exception instructions are historical.


### 2026-10-24 — Revisions: accept the owned local behavior independently of #441

TL b532446a excludes the independently demonstrated main/CLIProxy forced-tool failure from this issue's live acceptance. Keep the implementation and local question contract unchanged; rely on its passing both-runtime guards plus inside-Couch operator PASS, with the real standalone retry owned by unclaimed #441.


### 2026-10-24 11:01 — close round1 REWORK checkpoint

Fresh close measured6.21h normally on27c670ca; no actual bypass. Boundary review returned REWORK with BR-1 legacy-evidence-preservation, BR-2 attention-event-admission and BR-3 core-concept-purity. Nothing finalized; issue remains working. Generated close-gate/review sidecars retain the findings and measured inputs.

BR-2 reproduced:41finder cases pass and the new parent-removal/rewrite sequence fails; the production branch now forwards established rewrite events while leaving all new/retired discovery proof unchanged. Both-runtime qualification is in progress. BR-3 promotes the existing filesystem loader to integration, moves its eight file-backed tests and updates mapping/plan seams; preferred mapped review run passes with clean census, compatibility qualification pending. Lessons record all three classes.

For BR-1, TL680cdca5 retains the existing scalar/list subset and forbids a YAML node skipper. The RED matrix includes ignored default/other values beside chat/default evidence in flow/block forms. Production held while deciding unsupported-node safety: {chat:[Notes], other:{nested:false}} and reversed field order cannot reliably preserve partial evidence with the existing seam. Proposed narrow local-mutation refusal for an explicitly unread collaboration declaration is pending TL response; ordinary closed-header cases without that declaration must keep body commands. Stage remainsa4cebca0; no live checkout edits or #441 fix. After approved corrections, fresh recorded pre-close on the changed code head and a full re-close are required before merge.


### 2026-10-24 11:01 — approved unread-map safety boundary

TLb34bb4e7 explicitly approves local mutation refusal when an explicitly declared legacy collaboration map cannot be read, with clear notice/use-Couch recovery and both nested ignored-node orderings as tests. No-declaration headers retain today's body-command behavior. This supersedes the pending decision above. TL680cdca5 retains supported scalar/list evidence handling and historical strict parse behavior. Plan Revisions and visible-state table record the bounded rule before implementation; no general YAML node skipper or guessed partial extraction.


The supported BR-1 matrix returned RED on each runtime:5passed/52failed/0errors, with strict legacy22passing. All four unsupported nested-node orderings also reproduced unread notice plus unsafe local acceptance; they need the newly approved local refusal. BR-2 mapped functional tests pass314each plus the corrected traceability guard28each, with all final censuses clean. The only transient mapped-batch failure was the concurrently introduced unmapped BR-1 spec, now registered in modes/review and rechecked; no product flake inferred.
