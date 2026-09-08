# Boundary Review — parley.nvim#214 (milestone M3)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | d5ba3ebca28f42a93cf95ed132bd695c12f29c50..1c8699e47312093dcd294ac9a5b69d9bbf3ac9ca |
| command | sdlc milestone-close --issue 214 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-07T16:42:25-07:00 |
| verdict | unknown |

## Review

Failed to authenticate. API Error: 401 OAuth access token has been revoked.

---

## Re-review — 2026-09-07T18:11:18-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | d5ba3ebca28f42a93cf95ed132bd695c12f29c50..4d49383d7eee2b1d8a19001ef4a1c8322d3e1056 |
| command | sdlc milestone-close --issue 214 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-07T18:11:18-07:00 |
| verdict | REWORK |

## Review

I've completed the review. Full suite, luacheck, targeted reverts, and three reproduction probes were run.

```verdict
verdict: REWORK
confidence: high
```

M3 lands a genuinely good shape — the pure/IO split is real, the `🔒:`/`🌿:` latch fix is the right root-cause fix and is pinned by a test I confirmed goes red when reverted, and the NUL-byte defect is pinned by raw-byte assertions that also go red when reverted. What blocks SHIP is that the headline behaviour is wrong in a reachable case and the evidence that would have caught it does not exist: the reference position is computed *before* `apply_text_edits` strips the markers and used *after*, so whenever the strip changes the line count the `🌿:` block lands off-cursor — I reproduced three variants, one of which puts the reference **after** the `📝:` summary, which is exactly the relocation the operator revised the design twice to eliminate. Separately, the plan's Task 7 agreement check and four mutation-ledger rows are marked delivered but describe tests and code that are not in the tree, and the equivalence they were supposed to protect (`<M-i>` submits what `<M-CR>` would submit) is already false in two measurable ways.

---

## 1. Strengths

- **`chat_parser.lua:598-620` — the latch removal is the right fix at the right level.** The single-line annotation change is a root-cause fix (AGENTS.md "Root Cause"), not a workaround, and the atlas records the measurement (`atlas/chat/parsing.md:60-96`) rather than the conclusion.
- **`tests/unit/annotation_lines_spec.lua:79-90` is real protection, verified.** I reverted the trailing-trim `annotation_line(trimmed_end)` clause in a scratch copy: the span test goes red with `answer.line_end=14 includes the branch reference at 14`. The claim in the issue is accurate.
- **The NUL defect is pinned as a class.** Reverting only the `turn` splitting (`init.lua:4902-4920`) reddens 1 test; reverting `flatten_lines` as well reddens 3. Reading raw bytes rather than `readfile` (`branch_child_spec.lua:672-677`) is the only oracle that could have seen this — good instinct.
- **`tests/arch/single_source_sweeps_spec.lua:655-680` labels its own weakness honestly** ("the guard is currently unreachable... no behavioural test can distinguish it from its own absence"). That is the right way to ship a source-level assertion.
- **`branch_submit.lua:57-77` records why the destructive reading was dropped**, including the reachability argument (three keys, one callback). Deleted-code rationale that survives in the module header is the useful kind.

## 2. Critical findings

**C1 — `lua/parley/init.lua:2336-2347`: the reference position is computed before the strip and used after it.**
`plan.ref_after` is the pre-strip cursor line, but `buffer_edit.apply_text_edits` runs first and can change the line count. Its return value (`line_delta`, `buffer_edit.lua:203`) is discarded, and no extmark anchor is taken — while `chat_respond.lua:1299` solves exactly this with `buffer_edit.make_handle(buf, exch_end)` before the same call.

Reproduced (transcripts + cursor positions in the probe, all three drift by one line):

| case | expected | actual |
|---|---|---|
| standalone `🤖[…]` above the cursor | ref directly after cursor line, one blank each side | two blanks before the ref, **zero after** — the ref abuts `📝: sum` |
| cursor on the last line, marker above | ref after the cursor line | ref appended past the summary |
| multi-line `🤖[a\nb]` above the cursor | ref at the cursor | ref lands **after `📝: the summary`** |

The standalone form is the ordinary one — `<M-q>` on a blank line produces it (`drill_in_insert`, `init.lua:2120-2129`) — and `gather_edit_plan` deletes the intervening newline for it (`drill_in.lua:443-446`). The only integration test for this path (`branch_child_spec.lua:398-417`) uses an *inline* marker, which has zero line delta, so it confirms one interleaving and reports no coverage of the rest (`ARCH-ORDER` at-review). Fix: take a `buffer_edit.make_handle` on the cursor line before `apply_text_edits`, read it back after, and add a case with a standalone marker above the cursor.

**C2 — plan + issue Core-concepts tables describe a `plan_submission` that does not exist.**
`workshop/plans/000214-branch-submit-m3-plan.md:29-41` and the issue's `## Core concepts` both specify `case = "quotes" | "question"`, `question`, `topic`, and `delete_lines`. `lua/parley/branch_submit.lua:96-100` returns `{ case = "quotes", ref_after, strip_markers }` and nothing else. Task 3's checked-off steps (`plan:186-236`) list six tests asserting `p.delete_lines`, `case == "question"` and `p.question`; none exist in `tests/unit/branch_submit_spec.lua`. The four `## Deviations` entries do not cover the removal.

**C3 — Task 7 is marked delivered, the test does not exist, and the promise it guarded is already broken.**
`plan:314-320` checks off "pin the chord against `<M-CR>`'s documented rules", and `## Deviations` item 2 states "the check now runs `plan_submission`'s exchange resolution against `init.lua`'s `find_exchange_at_line` line-by-line over three transcripts. Verified by deleting the planner's margin rule: three tests go red." `grep -rn find_exchange_at_line tests/` returns only `tests/unit/pure_functions_spec.lua`; `plan_submission` contains no exchange resolution and no margin rule. Three mutation-ledger rows (`case 3b deletes the replaced answer`, `ref lands after 📝:`, `planner agrees with find_exchange_at_line`) mutate code that is not in the tree.

The unguarded promise is already false, two ways:
- `init.lua:2329` hardcodes `bracket = true`; `chat_respond.lua:1284` reads `config.mark_reference_span ~= false`. With that option off, `<M-i>` injects `[…]` brackets into the parent that `<M-CR>` would not.
- `<M-i>` gathers **buffer-wide**; `<M-CR>` with the cursor inside an exchange gathers only that exchange (`chat_respond.lua:1287-1294`) and, when the cursor sits on an answered exchange, does not fall through to the whole-buffer branch at all (`:1336-1345`). `branch_submit_spec.lua:104-115` asserts the buffer-wide behaviour as intended, so the divergence is deliberate but the "exactly as `<M-CR>` would strip them" claim in `README.md:174`, `atlas/chat/inline_branch_links.md:31` and `branch_submit.lua:5-6` is not.

## 3. Important findings

**I1 — `README.md`: the `gf` bullet was deleted as collateral.** `git show d5ba3eb:README.md` line 179 documents `gf` smart go-to-file; it is absent at HEAD and `gf` is still a shipped registry binding. It was removed inside the `<M-i>` bullet rewrite.

**I2 — `tests/unit/annotation_lines_spec.lua:20`: a unit spec calls `parley.setup({})` per test, and `make test` is not reproducibly green from a clean environment.** Two of two `make test-clean-env && make test-unit` runs failed; the annotation spec's failure is `E739: Cannot create directory .../xdg/data/nvim: file already exists`, raised from `file_tracker.lua:29` (`isdirectory` check then `mkdir`, raced by the 8-way runner). It passes standalone and in four warm-env runs. The spec tests `parse_chat`, which `tests/unit/parse_chat_spec.lua` already proves needs only a config stub and no `setup()` at all.

**I3 — `init.lua:2350-2352`: the write is guarded, the create is not, after the parent is already mutated.** `commit_reference` wraps `:write` in `pcall`; `create_child_if_owned` calls `M.create_child_chat` bare. By that point the markers are stripped and the `🌿:` line inserted, so a raise (unwritable `chat_dir`, full disk) escapes the keymap callback leaving a parent that points at a file that does not exist. This is plan-gate finding PQ-8, still open, shipped unchanged.

**I4 — `🔒:` now sends previously-withheld content to the LLM, with no upgrade note.** `atlas/chat/format.md` documented `🔒:` as a *section* excluded from LLM context; it is now one line. A user whose transcripts used the documented semantics silently starts submitting everything after the first noted line. The atlas records the change; `README.md` has no upgrade or breaking-change section and never documented the prefix.

## 4. Minor findings

- `init.lua:2266-2278` — `ready_marker_lines` computes a `line` per marker that `plan_submission` never reads, and runs `drill_in.parse` over the whole buffer a second time (`gather_edit_plan` parses again at `:2329`).
- `chat_parser.lua:335-342` — `annotation_line`'s comment says it reuses `highlight_structure.classify`; it re-matches `local_pattern`/`branch_pattern` directly instead. The closure is also rebuilt on every `finalize_component` call.
- `lua/parley/branch_ref.lua:44,54` — `--- @param selected string` appears twice in one docblock.
- `workshop/issues/000214-curate-default-keybindings.md:507` — revision entry 11 was written *into the middle* of the M3 Plan bullet (b9fc6c8), severing "Rows 2a/2b collapse" from "(placement is the cursor…)" and putting a `###` heading inside `## Plan`. `## Revisions` is at line 764.
- `init.lua:2331` — the `#blocks == 0` log says "markers found but none ready", but `ready_marker_lines` already filtered on `marker.ready`; reaching that branch means `parse` and `gather_edit_plan` disagreed, which the message hides.
- `insert_planned` does not `startinsert!` on the child while the fallback path does — same key, two landing modes.

## 5. Test coverage notes

- **Verified by reversion (good):** trailing-trim annotation skip → 1 red; `create_child_chat` turn splitting → 1 red; turn splitting + `flatten_lines` → 3 red.
- **Full suite:** `make lint` clean (0/0 across 355 files). `make test` green in warm-env runs; red from a clean env — see I2.
- **The gap that shipped C1:** every quotes-case test uses an inline marker. One standalone-marker fixture would have caught it. There is no seam to inject a nonzero `line_delta`, so the assertion set cannot distinguish "the cursor was used" from "the cursor happened to still be valid."
- The `<M-CR>` equivalence has no derived check at all (C3), which is what leaves the two divergences invisible.

## 6. Architectural notes

- **`ARCH-DRY` — flag.** `annotation_line` re-derives a predicate the classifier owns; `drill_in.parse` runs twice per keypress; `<M-CR>`'s case rules are restated in prose rather than shared (the plan names this as an accepted risk, which is fine — but then C3's check was the mitigation, and it is absent).
- **`ARCH-PURE` — flag.** `plan_submission` is pure but near-vacuous: `#exchanges > 0 and #markers > 0`. The decision that actually matters — where the reference goes *after* the edit — lives in the IO shell, which is precisely why C1 has no unit test. Moving the post-edit position calculation behind the pure seam would make it testable.
- **`ARCH-PURPOSE` — flag.** Task 7 is the chord's whole promise and is marked delivered without existing (C3).
- **`ARCH-MOCK` — pass.** No new external binary or service; the filesystem is exercised through real temp dirs, consistent with the repo's existing integration pattern.
- **`ARCH-CONSTRAINTS` — flag (minor).** The keypress does a full-buffer read, one `parse_chat`, and two `drill_in.parse` passes. One-shot and bounded, but this repo has an explicit perf discipline and one of the two parses is pure waste.
- **`ARCH-SECURE` — flag.** I4: user content marked private under the documented semantics now leaves the machine on upgrade, silently.
- **`ARCH-ORDER` — flag.** C1 is the canonical instance: a position carried across an external edit with no re-anchoring, and a test that can observe only the zero-delta interleaving. I3 is the second: an error path that unwinds the sequencing while leaving the in-flight buffer mutation in place.

## 7. Plan revision recommendations

Add a `## Revisions` entry to **`workshop/plans/000214-branch-submit-m3-plan.md`** covering:
1. `plan_submission` returns only the `quotes` case; `question`, `topic`, `delete_lines` and `case = "question"` were removed. Rewrite the Core concepts block (`:29-41`) and Task 3's step list (`:186-236`) to the shipped shape.
2. Task 7 was not implemented. Uncheck it, and either write the agreement check or state in the plan that `<M-i>` deliberately gathers buffer-wide with `bracket` forced on and amend the "exactly as `<M-CR>` would" wording in README/atlas/module header to match.
3. Remove the three mutation-ledger rows for code that is not in the tree and regenerate the ledger from `git diff d5ba3eb -- lua/`, as the section header claims it was.

Mirror (1) into the issue's `## Core concepts` `plan_submission` bullet, and move revision 11 out of the M3 Plan bullet into `## Revisions`.

```findings
findings:
  - id: new
    severity: Critical
    family: stale-position-across-buffer-edit
    title: |
      the 🌿: reference position is computed before the marker strip and used after it
    detail: |
      init.lua:2336-2347 applies marker_edits, then inserts at plan.ref_after — the
      PRE-strip cursor line. apply_text_edits returns line_delta (buffer_edit.lua:203)
      and it is discarded; chat_respond.lua:1299 solves the same problem with
      buffer_edit.make_handle. Reproduced three ways: a standalone 🤖[…] above the
      cursor (drill_in.lua:443-446 deletes the newline), a cursor on the last line,
      and a multi-line 🤖[a\nb]. In the third the reference lands AFTER 📝: the
      summary — the relocation the operator revised the design twice to remove — and
      in the first the "one blank line each side" MARGIN invariant breaks (two before,
      zero after). The only quotes-case integration test uses an inline marker, whose
      delta is zero, so it observes one interleaving and reports no coverage
      (ARCH-ORDER). Fix: anchor the cursor line with make_handle before
      apply_text_edits and read it back, and add a standalone-marker fixture.
  - id: new
    severity: Critical
    family: plan-not-revised-after-decision-change
    title: |
      the plan's and issue's Core concepts tables describe a plan_submission the code does not implement
    detail: |
      This is the 2nd finding in family `plan-not-revised-after-decision-change`.
      Do not patch the one table — state the rule: when a decision removes a field or
      a case from a Core-concepts entity, the SAME commit rewrites every artifact that
      restates that entity (plan table, plan task steps, issue Core concepts, mutation
      ledger) and records the removal under `## Deviations`, because those artifacts
      are what the next agent reads instead of the code.
      plan:29-41 and the issue's `## Core concepts` specify case = "quotes"|"question",
      question, topic and delete_lines; branch_submit.lua:96-100 returns only
      { case = "quotes", ref_after, strip_markers }. Task 3's checked steps (plan:186-236)
      list six tests asserting p.delete_lines / case == "question" / p.question, none of
      which exist in tests/unit/branch_submit_spec.lua. The four `## Deviations` entries
      do not mention the removal.
  - id: new
    severity: Critical
    family: docs-assert-unverified-behavior
    title: |
      Task 7's <M-CR> agreement check is checked off but absent, and the equivalence it guarded is already false
    detail: |
      This is the 6th finding in family `docs-assert-unverified-behavior`. Earlier
      rounds fixed instances. Do not fix this instance alone — the rule is: a plan step
      may not be checked off, and a `## Deviations` entry may not describe a test, until
      that test exists in the tree and has been seen red; the mutation ledger is
      generated from `git diff <base> -- lua/` and a row whose mutation target is not in
      the diff is a defect in the ledger, not a note.
      plan:314-320 checks off the agreement pin; `## Deviations` item 2 claims it "runs
      plan_submission's exchange resolution against init.lua's find_exchange_at_line
      line-by-line over three transcripts. Verified by deleting the planner's margin
      rule: three tests go red." grep -rn find_exchange_at_line tests/ hits only
      tests/unit/pure_functions_spec.lua; plan_submission has no exchange resolution and
      no margin rule. Three ledger rows (case 3b delete_lines, ref lands after 📝:,
      planner agrees with find_exchange_at_line) mutate code that is not in the tree.
      The unguarded promise is already broken twice: init.lua:2329 hardcodes
      bracket = true where chat_respond.lua:1284 reads config.mark_reference_span, and
      <M-i> gathers buffer-wide where <M-CR> gathers per-exchange
      (chat_respond.lua:1287-1294, :1336-1345) — so README.md:174,
      atlas/chat/inline_branch_links.md:31 and branch_submit.lua:5-6 all assert an
      equivalence that does not hold.
  - id: new
    severity: Important
    family: readme-missing-for-changed-surface
    title: |
      the gf smart go-to-file bullet was deleted from README as collateral of the <M-i> rewrite
    detail: |
      This is the 3rd finding in family `readme-missing-for-changed-surface`. Do not
      just restore the line — state the rule: README's binding list and the registry's
      resolved default keys must agree, and that agreement should be derived, not
      reviewed. M2 already built the machinery (keybinding_agreement_spec.lua, key_for)
      and already caught three README-documented commands that were never implemented;
      extend the same derivation to bindings so a bullet cannot vanish silently.
      `git show d5ba3eb:README.md` line 179 documents `gf`; it is absent at HEAD and
      `gf` is still shipped.
  - id: new
    severity: Important
    family: test-harness-assumption
    title: |
      the new unit spec calls parley.setup() per test, and make test is red from a clean environment
    detail: |
      This is the 4th finding in family `test-harness-assumption`. Do not fix only the
      new spec — the rule is: a spec in tests/unit/ exercises pure logic with an
      injected config stub and never calls parley.setup(), and the shared IO it would
      have touched must be race-safe rather than trusted to serialise.
      Two of two `make test-clean-env && make test-unit` runs failed; the annotation
      spec fails with E739: Cannot create directory .../xdg/data/nvim: file already
      exists, from file_tracker.lua:26-31 (isdirectory check then mkdir, raced by the
      8-way runner). It passes standalone and in four warm-env runs, and
      artifact_ref_spec.lua — one of 21 pre-existing unit specs that call setup() —
      failed the same way on the other clean run. annotation_lines_spec tests
      parse_chat, which tests/unit/parse_chat_spec.lua already covers with a plain
      config stub and no setup at all. Class fix: drop setup() from the new spec, and
      make ensure_dir_exists tolerate an existing directory.
  - id: new
    severity: Important
    family: partial-effect-not-committed
    title: |
      create_child_chat is unguarded after the parent has already been stripped and the reference inserted
    detail: |
      This is the 4th finding in family `partial-effect-not-committed`. Do not guard
      the one call — the rule is: within a single keypress transition, every effect
      after the first buffer mutation is guarded the same way, and a failure states
      what the buffer is left holding. Right now the guarding is inconsistent within
      ten lines of the same function.
      init.lua:2350 calls create_child_if_owned bare while :2351 calls commit_reference,
      which pcalls its :write. By :2350 the markers are stripped and the 🌿: line
      inserted, so a raise (unwritable chat_dir, full disk) escapes the keymap callback
      leaving a parent pointing at a file that does not exist. This is plan-gate finding
      PQ-8, still open at that gate, shipped unchanged.
  - id: new
    severity: Important
    family: breaking-change-without-upgrade-note
    title: |
      🔒: content previously withheld from the LLM is now submitted, with no upgrade note
    detail: |
      atlas/chat/format.md documented 🔒: as a local SECTION excluded from LLM context;
      chat_parser.lua:606-613 makes it one line. A user whose transcripts used the
      documented semantics silently begins submitting every line after the first noted
      one on their next request. The measurement cited (0 of 16 chats in the operator's
      corpus) bounds the operator's exposure, not a published plugin's users. The atlas
      records the new behaviour; README has no upgrade or breaking-change section and
      never documented the prefix, so there is nowhere a user would see this
      (ARCH-SECURE at-review).
  - id: new
    severity: Minor
    family: dead-value-in-new-code
    title: |
      ready_marker_lines computes a line number per marker that plan_submission never reads
    detail: |
      This is the 2nd finding in family `dead-value-in-new-code`. Do not just delete
      the field — the rule is: a value computed to satisfy a signature must be read by
      that signature's implementation, or the parameter goes away; a dead field in a
      "pure decision" module is what makes the module look like it decides more than it
      does. init.lua:2266-2278 counts newlines per ready marker to build { line = N };
      branch_submit.lua:87-101 only tests #markers > 0. The same pass also runs
      drill_in.parse over the whole buffer a second time — gather_edit_plan at :2329
      parses again.
  - id: new
    severity: Minor
    family: duplicate-helper-not-retired
    title: |
      annotation_line re-implements the classifier's predicate while its comment claims it reuses it
    detail: |
      This is the 7th finding in family `duplicate-helper-not-retired`. Earlier rounds
      fixed instances. Do not fix this instance — the rule is: a line-kind predicate
      lives in highlight_structure beside the patterns it reads, and callers ask it
      rather than re-matching pattern fields; highlight_structure.is_partition
      (:180-198) is the precedent for exactly this. chat_parser.lua:335-342 defines
      annotation_line inline (rebuilt per finalize_component call) matching
      local_pattern/branch_pattern directly, under a comment asserting it reuses
      highlight_structure.classify. Add is_annotation(line, patterns) there and call it.
  - id: new
    severity: Minor
    family: markdown-block-not-separated
    title: |
      revision 11 was written into the middle of the M3 Plan bullet instead of into ## Revisions
    detail: |
      This is the 2nd finding in family `markdown-block-not-separated`. Do not just move
      this block — the rule is: a `## Revisions` entry is appended to `## Revisions`,
      never inlined into the artifact section it revises, and its number is unique
      across the issue.
      workshop/issues/000214-curate-default-keybindings.md:507 puts a `###` heading and
      its body between "Rows 2a/2b collapse" and "(placement is the cursor, not the
      exchange end)", severing the bullet and nesting a heading inside `## Plan`.
      `## Revisions` is at :764, and the numbered entries 1-11 are currently split
      across `## Plan`, `## Log` and `## Revisions` with 1/2/3 used twice.
```
