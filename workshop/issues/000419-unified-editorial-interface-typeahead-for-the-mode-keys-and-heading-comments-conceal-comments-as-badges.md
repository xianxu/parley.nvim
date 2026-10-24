---
id: 000419
status: working
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '2325c3a3f62f8f396340bacbd91f4f98784a7745' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T11:08:07-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# unified-editorial-interface: typeahead for the mode keys and heading comments; conceal comments as badges

## Problem

## Spec

**Active contract, 2026-10-23:** one collaborative behavior, `@@chat@@` sections, and highlight for new edits. The operator pivot and TL allocation supersede the historical three-axis interface below. Source contract and exported fixtures are pinned to landed ariadne#576, Git `354e5fac5c96e0b2c26350ee712eb835746a6d67` (PR420). Preserve legacy metadata; create no mode keys or standing instruction. Remove existing mode/selector completion as well as omitting new typeahead.

Share one snapshot-derived chat projection between admission/protection, tag decoration and heading attachment. A standalone tag directly above a parsed ATX heading, outside code, is chat; boundaries, legacy scalar/maps/comments, nested item grammar and exact notices follow the pinned source. Malformed or retired mode metadata emits notices and never refuses an otherwise valid round. Keep `@@chat@@` visible with a light highlight; ordinary tags and references retain their behavior.

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
- The production chat projection matches pinned tag/legacy contexts and exact notices, including empty collaboration-mode and a leading thematic break. Duplicate normalized headings all match; nesting, code and literal exclusions are covered.
- A valid tag remains visible and lightly highlighted and moves with its heading through native section operations. Moving/deleting the preceding section does not take it; ordinary tags/references and the established editing-heading dialect stay compatible.
- Outside Couch, commands apply through the existing write owner; questions remain unchanged with the exact limitation notice above. Mixed question/command batches preserve questions, and missing/malformed classification cannot cause a write. No local side docs are created.
- Monthly side docs, actual parents, same-root grandchildren, old flat files and existing linked qa files retain correct navigation/ownership and attention. Recursive document moves preserve links, backlinks and index entries using the existing transaction owner.
- New round edits highlight; stored mixed/legacy rounds retain per-span > round > highlight fallback with strict validation and unknown-field preservation where rewritten.
- Both supported Neovim runtimes pass mapped unit/native/conformance tests, counted N/2N growth controls and a fresh recorded suite. Hub-arranged live acceptance verifies tag display/moves, Couch question-to-link behavior, monthly link navigation and the local question limitation.

<details>
<summary>Superseded original acceptance — historical evidence</summary>

- Typing `<!-- ` under a heading offers the three keys; `key: ` offers its values; `; ` offers only unused keys; the
  closing ` -->` is inserted (tests on both nvim versions).
- Frontmatter key and value completion covers all three keys (test).
- The comment renders as a badge and reveals on the cursor line (test).

</details>

## Plan

- [ ] Approve the durable plan in `workshop/plans/000419-collaborative-chat-interface-plan.md` with the hub.
- [ ] Implement pinned policy/bundle, single-buffer admission, tag/heading ownership, side-doc readers and historical round compatibility using existing effect owners.
- [ ] Verify both runtimes, obtain live acceptance, close on the recorded suite and land.

## Log

### 2026-10-22


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
