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

---

## Re-review — 2026-09-07T18:32:20-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | d5ba3ebca28f42a93cf95ed132bd695c12f29c50..b751580ec773fb971cdf0567f4862738d96f5ae0 |
| command | sdlc milestone-close --issue 214 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-07T18:32:20-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M3's shape is right and most of last round's work landed: the `🌿:`/`🔒:` latch removal is a real root-cause fix pinned by a span test, the NUL-byte defect is pinned by raw-byte assertions, `chat_gather_opts` genuinely single-sources the gather options (swept: two consumers, both derive), and BR-63's ordering fix is real and tested. Full `make test` is green twice from a clean environment (200 spec files, `MAKE_EXIT=0` both runs) and `luacheck` is clean across 355 files. What blocks SHIP is that **BR-58 is not actually fixed** — I reproduced the reference landing *above* the cursor line, with a runnable probe, in an ordinary configuration the new tests do not cover: the extmark is anchored one row too low, onto the whitespace gap that `gather_edit_plan` swallows into its closing `]`. That is the same symptom the operator revised the design twice to eliminate. Alongside it, the `## Deviations` section of the M3 plan was never touched, so it still asserts a test that does not exist (BR-60) and still records no removal entry (BR-59), and BR-61's derivation was not built.

---

## 1. Strengths

- **`lua/parley/chat_parser.lua:601-620` — the latch removal is the right level of fix.** Single-line annotations replace a mode, and the trailing-trim clause at `:335-348` that keeps a trailing `🌿:` outside `answer.line_end` is the non-obvious consequence the author found rather than shipped past. `tests/unit/annotation_lines_spec.lua:96-107` is genuine protection.
- **`lua/parley/init.lua:2318-2329` — BR-63 fixed by ordering, not by a wrapper.** Creating the child before the first buffer mutation removes the window instead of unwinding inside it, and `tests/integration/branch_child_spec.lua:820-838` simulates the failure and asserts the markers survive. Reachable, and it would go red without the reorder.
- **`lua/parley/drill_in.lua:346-361` — `chat_gather_opts` is a real single source.** I swept every consumer: `chat_respond.lua:1282` and `init.lua:2304` are the only two, and both derive. The guard at `branch_submit_spec.lua:148-160` closes it from the source side.
- **`tests/arch/single_source_sweeps_spec.lua:655-666` labels its own weakness** ("no behavioural test can distinguish it from its own absence"). That is the honest way to ship a source-level assertion.
- **`workshop/lessons.md:1490-1531` rule 1** ("the test must mutate a different amount than zero") names exactly the right axis — see the Critical below for the dimension of that axis it did not sweep.

## 2. Critical findings

**C1 — `lua/parley/init.lua:2336-2340`: BR-58's anchor is one row low and sits inside the strip's deletion range; the reference still lands off the cursor.** *(disposed `not-addressed` under BR-58, not re-raised as new)*

`buffer_edit.make_handle(buf, plan.ref_after)` takes a **0-indexed** row, and `plan.ref_after` is the **1-indexed** cursor line — so the extmark is planted on the line *after* the cursor. `drill_in.lua:457-458` emits a single edit `edit(se + 1, marker.byte_end + 1, "]")` whenever the gap between the bracketed span and a standalone marker is whitespace-only; that range covers the newlines and blank line *below* the cursor line, i.e. exactly where the anchor is. With `right_gravity = false` the mark collapses to the range start, and the reference is inserted **before** the cursor line.

Reproduced (probe run against `b751580`, full transcripts available on request):

| fixture | cursor | expected | actual |
|---|---|---|---|
| standalone `🤖[…]` directly below the cursor line, blank between | `the cursor line` | ref after it | **ref at 11, `[the cursor line]` at 12 — ref is above the cursor** |
| two markers, inline above + standalone directly below | `the cursor line` | ref after it | **ref at 13, `[the cursor line]` at 14 — plus a double blank at 11-12** |
| inline marker below the cursor | — | ref after cursor | correct |
| standalone marker below, separated by prose | — | ref after cursor | correct |
| standalone/multi-line marker above the cursor; cursor on last line | — | ref after cursor | correct |

Every new integration test puts the marker **above** the cursor (`branch_child_spec.lua:404-460`), so the suite samples one side of the axis. This is the same ARCH-ORDER flag as last round, one dimension over: the lessons entry identified the *delta* axis and swept it, but not the *position of the marker relative to the anchor* axis, which is what selects the deletion-range-vs-anchor interaction.

Fix sketch: anchor the **cursor line itself**, not the line after it —
```lua
local anchor = buffer_edit.make_handle(buf, plan.ref_after - 1)
buffer_edit.apply_text_edits(buf, 0, text, marker_edits)
local insert_at = buffer_edit.handle_line(anchor) + 1
```
The cursor line's start byte is before `se + 1` in every case above, so the mark survives the `]` edit. I traced this against all six probe fixtures and it gives the correct position in each. Add a fixture matrix over `{inline, standalone, multi-line} × {above, on, directly-below, below-with-prose}` — the below-directly cases are what the current suite cannot see.

## 3. Important findings

**I1 — the "one blank line each side" margin is asserted in three artifacts and held by neither path.** `init.lua:2343-2345` inserts `{ "", ref }` — one blank *before* only — under a comment claiming "one blank line each side". `insert_plain` (`init.lua:2387-2390`) inserts the bare line with **no** blank on either side. The plan (`000214-branch-submit-m3-plan.md`, M3 Plan bullet in the issue) says `add_block(k, "branch_ref", 1, 1)`; `grep` finds no `branch_ref` block kind in `exchange_model.lua` at all. Measured: with the cursor line followed immediately by non-blank prose, the reference abuts the next line (no blank after); in the two-marker case above, two blanks precede it. The existing assertions (`branch_child_spec.lua:397, 419-420`) pass only because those fixtures happen to have a blank line in the right place — the same size-one sample as C1. Fix: normalise (blank before only if the previous line is non-blank, blank after only if the next line is non-blank) in one helper both paths call, and make the fixture put non-blank text on both sides.

**I2 — the pending-response refusal covers `n`/`i` but not `v`, while README and atlas state it for the whole chord.** `init.lua:2288` guards `insert_planned`, which only `insert_plain` reaches; `insert_inline` (`init.lua:2425-2452`) runs `create_child_if_owned` + `commit_reference()` with no check. `README.md` ("It declines while a response is still streaming into that chat", in the paragraph closing all three bullets) and `atlas/chat/inline_branch_links.md:60-62` ("**Refusals.** The chord declines while the buffer owns a pending response") both assert it unconditionally. `init.lua:2216-2219` already states the governing rule for this file — "The enumeration is the dispatch table below — n, i, v — not 'the path I happened to be looking at'." Either lift the guard above the dispatch table so all three entries get it, or narrow both documents to the paths that have it.

**I3 — `atlas/chat/drill_in.md:130-137` still names `chat_respond` as the owner of the gather options.** It reads "`chat_respond` assembles them from config" and "`opts.bracket` (set by `chat_respond` from `config.mark_reference_span`)". As of this window the owner is `drill_in.chat_gather_opts` and there are two consumers. `atlas/chat/drill_in.md` is listed by name in the plan's Task 8 file list and is not in the diff. New surface (`chat_gather_opts`) with no update to its home atlas page — AGENTS.md §8.

## 4. Minor findings

- **M1 — `init.lua:2296` runs a full `parse_chat` on every `<M-i>` press to answer only `#exchanges == 0`**, including on the no-marker path where the result is discarded and the gather already answered the question. `M.parse_chat` is uncached (`init.lua:3709`). Ask the gather first, then parse only if a plan is possible.
- **M2 — the effects after the create are unguarded.** BR-63 moved the point of no return to `create_child_if_owned`; `apply_text_edits` and `nvim_buf_set_lines` at `:2337-2345` now run after it with no `pcall` and no statement of what the buffer is left holding. Low probability (the edits are drill_in's own), but the rule BR-63 stated still has an unswept half.
- **M3 — `tests/unit/branch_submit_spec.lua:135-140` "a question with no text has nothing to submit" is green for an unrelated reason** — it passes `has_markers = false`, and `plan_submission` never inspects `question.content`. `:129` likewise passes `{}` (truthy) for a boolean parameter, a leftover from the pre-narrowing signature.
- **M4 —** the source-level guard at `branch_submit_spec.lua:148-160` reads files off disk from `tests/unit/`; `tests/arch/single_source_sweeps_spec.lua` is where the repo puts that kind of assertion.
- **M5 —** `workshop/issues/000214-curate-default-keybindings.md:647-648` carries a stranded two-line fragment (`(placement is the cursor, not the exchange end) …`) left behind when revision 11 was moved out of the Plan bullet.

## 5. Test coverage notes

Two clean-environment `make test` runs, both green (200 spec files); `make lint` clean, 0/0 in 355 files. BR-62's clean-env flake did not reproduce in either — and the second half of its prescribed fix turns out to be unnecessary: I measured `vim.fn.mkdir(existing, "p")` on nvim 0.11.7 and it returns `1` without error, so `file_tracker.ensure_dir_exists` was never the race it was diagnosed as (every `mkdir` in `lua/` passes `"p"`).

The gap the suite has is the one C1 and I1 share: **every new fixture places the interfering element on the same side of the anchor.** Markers are always above the cursor; the cursor line always has a blank line after it. Both properties are incidental to what the tests set out to assert, and both are exactly what selects the passing branch. The mutation ledger row "reference survives the strip (BR-58) | keep the pre-strip line number | 2 integration" is accurate as far as it goes — the fix is reachable, and reverting it would redden those two — but a mutation that only proves the anchor *does something* does not establish that it anchors the right row.

## 6. Architectural notes

- **ARCH-DRY — pass.** `chat_gather_opts` genuinely consolidates; the four-function branch collapse from M1 holds; `seed_question` retired the second `what is "X"` at `init.lua:3251-3257`. The one live duplication is `chat_parser.annotation_line` re-matching `local_pattern`/`branch_pattern` instead of asking `highlight_structure` (BR-66, disposed `not-addressed`) — now correctly commented and hoisted out of the closure, but the predicate still does not live beside the patterns.
- **ARCH-PURE — pass.** `plan_submission` and `seed_question` are pure and unit-tested with hand-built inputs, no buffer. The effects stay in `branch_inserters`. The one wrinkle: `plan_submission` has been narrowed to the point where it takes three parameters and reads two, which is worth watching if M4 re-widens it.
- **ARCH-PURPOSE — pass with a note.** The narrowing to the quotes case is an operator decision, recorded, and the fallback preserves M1's affordance. The single-source sweep for gather options is complete. What is *not* complete is the class fix for BR-61: the instance (`gf`) was restored, the derivation that would stop a README bullet vanishing was not built. That is the instance, not the class.
- **ARCH-MOCK — N/A.** No new external binary or service; `chat_pending.identity` is internal state, and the test's substitution is a seam over our own module.
- **ARCH-CONSTRAINTS — flag (Minor).** This is an interactive keypress path that now performs two full-buffer parses, one of which is discarded on the most common branch (M1). No envelope is declared for it in the plan; the repo otherwise takes full-buffer work on interactive paths seriously (`perf_chat_typing_spec`).
- **ARCH-SECURE — pass.** No credential surface. The one new untrusted-input path is the gathered marker text becoming a `🌿:` label and a child question; `topic_for_selection` collapses newlines so the label cannot break the line format, `create_child_chat` avoids `gsub` replacement for it, and `flatten_lines` closes the NUL vector at the writer. The `🔒:` semantic change *is* a behaviour change for existing transcripts and now has the README upgrade note it lacked (BR-64 addressed).
- **ARCH-ORDER — flag (Critical).** The transition is written down in the plan and the module header, and the pending-response case is handled. But the tests observe one interleaving on the axis that matters (C1), and the enumeration in the header does not name "where the markers sit relative to the anchor" as an event dimension at all — which is why the fix for BR-58 could look complete.

## 7. Plan revision recommendations

The M3 plan's `## Deviations` section was not touched this round and is where three of the four not-addressed dispositions live. It needs:

1. **A new `## Deviations` entry recording the removal** of `case = "question"`, `question`, `topic` and `delete_lines` from `plan_submission` — BR-59 named this as part of the rule and it is still absent. In the same edit, **uncheck Task 3's Step 1 and replace its six draft assertions** with the three that exist, or delete the block and point at `tests/unit/branch_submit_spec.lua`. A `- [x]` over assertions that are not in the tree is what the rule forbids.
2. **Rewrite `## Deviations` item 2.** It still states verbatim that the check "runs `plan_submission`'s exchange resolution against `init.lua`'s `find_exchange_at_line` line-by-line over three transcripts. Verified by deleting the planner's margin rule: three tests go red." `grep -rn find_exchange_at_line tests/` hits only `pure_functions_spec.lua` and `chat_parser_section_lines_spec.lua`; there is no margin rule in `plan_submission`. Task 7's own body already carries the correction — item 2 contradicts it.
3. **`## Deviations` item 4** claims "the reference carries a `label`"; no test asserts the label's content. Either add the assertion or drop the claim.
4. **Add `chat_gather_opts` and `flatten_lines` rows** to the plan's Core-concepts tables. The issue's table has them (which is what keeps the arch guard green), but the plan's table is the artifact the M3 reader opens.
5. **The issue file:** move the numbered entries 9-11 into `## Revisions` (they currently sit under `## Log`, and numbers 1/2/3 are used twice across the two sections), and delete the stranded fragment at `:647-648`.

```findings
dispose:
  - id: BR-58
    disposition: not-addressed
    note: |
      make_handle takes a 0-indexed row but is passed the 1-indexed cursor line, so the
      anchor sits on the whitespace gap that drill_in.lua:457-458 swallows into its `]`
      edit; with left gravity the mark collapses and the ref lands ABOVE the cursor line.
      Reproduced: standalone marker directly below the cursor, and inline-above + standalone-below.
      Every new fixture puts the marker above the cursor, so the suite samples one side of the axis.
  - id: BR-59
    disposition: not-addressed
    note: |
      Core-concepts tables corrected in both plan and issue and the ledger rows struck, but
      the plan's Task 3 steps are still `- [x]` over six assertions absent from the tree, and
      `## Deviations` still records no entry for the removal — two of the four artifacts the rule named.
  - id: BR-60
    disposition: not-addressed
    note: |
      Task 7's body now says NOT DELIVERED and the ledger row is struck, but `## Deviations`
      item 2 still states verbatim that the check runs plan_submission's exchange resolution
      against find_exchange_at_line over three transcripts, verified by three red tests. No such test exists.
  - id: BR-61
    disposition: not-addressed
    note: |
      The `gf` bullet is restored, but the derivation the finding asked for was not built —
      no test relates README's binding bullets to the registry's resolved default keys, so the
      next bullet can still vanish silently. Instance fixed, class open.
  - id: BR-62
    disposition: addressed
    note: |
      setup() dropped from the new spec; two clean-environment `make test` runs green (200 files).
      The ensure_dir_exists half is unnecessary — measured that vim.fn.mkdir(existing, "p") returns
      1 without error on nvim 0.11.7, and every mkdir in lua/ passes "p".
  - id: BR-63
    disposition: addressed
    note: |
      Create now precedes every buffer mutation and is pcall'd; branch_child_spec.lua:820-838
      simulates the failure and asserts the markers survive. See Minor M2 for the unswept half
      (the effects after the create are now the unguarded ones).
  - id: BR-64
    disposition: addressed
    note: |
      README now carries an explicit upgrade note under "Two config contracts changed"; the atlas
      records the single-line semantics in both format.md and parsing.md.
  - id: BR-65
    disposition: addressed
    note: |
      ready_marker_lines is gone (grep: zero hits) and the second drill_in.parse pass with it;
      the gather is now asked first and is the authority. See Minor M1 for the parse_chat that remains unconditional.
  - id: BR-66
    disposition: not-addressed
    note: |
      The false comment is fixed and the closure hoisted out of finalize_component, but the
      predicate still re-matches local_pattern/branch_pattern in chat_parser instead of living in
      highlight_structure as is_annotation. A reasoned counter-argument is given in the comment; the stated rule is not followed.
  - id: BR-67
    disposition: not-addressed
    note: |
      The block no longer severs the Plan bullet, but the rule was not applied: entries 9-11 still
      live under `## Log` rather than `## Revisions`, numbers 1/2/3 remain duplicated across the two
      sections, and the move stranded a two-line fragment at issue :647-648.
findings:
  - id: new
    severity: Important
    family: docs-assert-unverified-behavior
    title: |
      the "one blank line each side" margin is asserted in three artifacts and held by neither insert path
    detail: |
      init.lua:2343-2345 inserts { "", ref } — one blank BEFORE only — under a comment claiming
      "one blank line each side"; insert_plain at :2387-2390 inserts the bare line with no blank on
      either side. The plan says `add_block(k, "branch_ref", 1, 1)` and no such block kind exists in
      exchange_model.lua. Measured: cursor line followed immediately by non-blank prose leaves the ref
      abutting the next line; the two-marker case leaves two blanks before it. The existing assertions
      (branch_child_spec.lua:397, 419-420) pass only because those fixtures happen to have a blank in the
      right place. Rule: an invariant stated in a comment or plan is pinned by a fixture that would violate
      it if the code were wrong — here, non-blank text on BOTH sides — and one key gets one spacing rule in one helper.
  - id: new
    severity: Important
    family: docs-assert-unverified-behavior
    title: |
      the pending-response refusal covers n and i but not v, while README and the atlas state it for the whole chord
    detail: |
      init.lua:2288 guards insert_planned, reachable only from insert_plain (n/i). insert_inline at
      :2425-2452 runs create_child_if_owned and commit_reference with no check. README.md's closing
      paragraph ("It declines while a response is still streaming into that chat") and
      atlas/chat/inline_branch_links.md:60-62 ("Refusals. The chord declines...") both assert it for all
      three cases. init.lua:2216-2219 already states the governing rule for this file: the enumeration is
      the dispatch table n/i/v, not the path in front of you. Lift the guard above the dispatch table, or narrow both documents.
  - id: new
    severity: Important
    family: stale-comment-after-move
    title: |
      atlas/chat/drill_in.md still names chat_respond as the owner of the gather options
    detail: |
      :130-137 read "chat_respond assembles them from config" and "opts.bracket (set by chat_respond from
      config.mark_reference_span)". The owner is now drill_in.chat_gather_opts with two consumers. The file
      is named in the plan's Task 8 file list and is absent from the diff — new surface with no update to its
      home atlas page (AGENTS.md section 8).
  - id: new
    severity: Minor
    family: derive-before-validate
    title: |
      a full parse_chat runs on every M-i press to answer only "are there zero exchanges"
    detail: |
      init.lua:2296 parses the whole buffer (M.parse_chat is uncached, init.lua:3709) before the
      has_markers check that decides whether a plan is possible at all; on the common no-marker path the
      result is discarded. Ask the gather first, then parse only when a plan can exist. ARCH-CONSTRAINTS:
      this is an interactive keypress path now doing two full-buffer passes with no declared envelope.
  - id: new
    severity: Minor
    family: partial-effect-not-committed
    title: |
      BR-63 moved the point of no return, and the effects after it are now the unguarded ones
    detail: |
      This is the 5th finding in family `partial-effect-not-committed`. Earlier rounds fixed instances.
      Do not guard the one call — the rule BR-63 stated still has an unswept half: within a single keypress
      transition, every effect after the point of no return is guarded the same way and a failure states what
      the buffer is left holding. create_child_if_owned is now pcall'd and first (init.lua:2329); the
      apply_text_edits and nvim_buf_set_lines at :2337-2345 that follow it are not, so a raise there leaves a
      child on disk with no reference — BR-19's orphan by the reverse route. Low probability, since the edits are drill_in's own.
  - id: new
    severity: Minor
    family: test-does-not-pin-the-fix
    title: |
      two plan_submission decline tests are green for reasons unrelated to their names
    detail: |
      This is the 6th finding in family `test-does-not-pin-the-fix`. Do not fix these two — the rule is:
      a test's name states the branch it takes, and the assertion fails if that branch is removed.
      branch_submit_spec.lua:135-140 "a question with no text has nothing to submit" passes has_markers = false
      and plan_submission never inspects question.content, so it exercises the marker branch and would stay
      green if the content check it names were added and then broken. :129 passes `{}` (truthy) for a boolean
      parameter, a leftover from the pre-narrowing signature, and passes only via the zero-exchanges branch.
  - id: new
    severity: Minor
    family: markdown-block-not-separated
    title: |
      a stranded two-line fragment remains at the issue's :647-648 after revision 11 was moved
    detail: |
      This is the 3rd finding in family `markdown-block-not-separated`. Do not just delete these two lines —
      the rule from BR-67 still applies and was not: a `## Revisions` entry is appended to `## Revisions`,
      never left in the section it revises, and its number is unique across the issue. Entries 9-11 are still
      under `## Log`; 1/2/3 are used twice; and the move left
      "      (placement is the cursor, not the exchange end) and the 3a/3b split is gone" dangling after revision 11's body.
```

---

## Re-review — 2026-09-07T18:56:41-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | d5ba3ebca28f42a93cf95ed132bd695c12f29c50..6e786ae9fb2f17f141dbeb7f576b27dad2416865 |
| command | sdlc milestone-close --issue 214 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-07T18:56:41-07:00 |
| verdict | REWORK |

## Review

Tree restored to its pre-review state (only the pre-existing workshop changes remain).

```verdict
verdict: REWORK
confidence: high
```

The prior round's four Criticals/Importants are genuinely fixed and each is pinned by a test I confirmed goes red when reverted (BR-58 anchor → 2 red, BR-68 `ref_block` → 1 red, BR-69 `refuse_while_pending` on `v` → 1 red). Full suite green, luacheck clean. What blocks SHIP is a regression this window introduced and did not sweep: removing the `line_before_local` latch put `🌿:`/`🔒:` annotation lines *inside* the component's line span, and the restoration covered only the **trailing** position. `<M-CR>`'s resubmit deletes `question.line_end+1 .. answer.line_end`, so a **mid-answer** reference — which is precisely where the M3 chord now puts one, by design — is deleted on the next resubmit, orphaning a child chat that exists on disk (BR-19's hazard, by the route the trim was added to close), and a mid-answer `🔒:` private note is silently destroyed with it. Measured end-to-end against a base worktree: `answer.line_end` is 10 at `d5ba3eb` and 16 at HEAD for the same transcript; after a real `<M-i>` at line 10 the reference lands at 12 and the resubmit span is 7..16.

### 1. Strengths

- **`drill_in.chat_gather_opts`** (`lua/parley/drill_in.lua:346-360`) is the right shape for BR-60: one owner, two consumers, and `branch_submit_spec.lua:153-161` asserts *neither call site rebuilds the options* rather than asserting today's values. That guard survives the next refactor.
- **The BR-58 fix samples both sides of the delta axis.** `branch_child_spec.lua:493-538` adds a marker *below* the cursor and a marker above-and-below, after round 1's fixtures all sat on one side. Reverting the `make_handle` anchor turns 2 tests red.
- **The NUL-byte tests read raw bytes** (`branch_child_spec.lua:833-838`), which is the only oracle that can see the defect — `readfile` turns the NUL back into `\n`. And `branch_child_spec.lua:871-879` is labelled as *not* coverage of `flatten_lines`, which is an unusually honest thing to write about one's own green test.
- **`refuse_while_pending` wraps the dispatch table, not a path** (`init.lua:2470-2489`), applying the enumeration rule the file already states. The test loops n/i/v rather than asserting the one mode that broke.
- **The `🔒:` semantic change ships with a real upgrade note** in `README.md`'s config-contract section, naming the user-visible consequence ("text you expected to stay private will now be submitted") rather than describing the code change.

### 2. Critical findings

**`lua/parley/chat_parser.lua:335-352` — a mid-component `🌿:`/`🔒:` is inside the span a resubmit deletes.**
*This is the 2nd finding in family `merged-path-loses-original-effect`.* Do not fix the trailing case again — state the rule: **when a latch is replaced by per-line handling, enumerate every effect the latch provided and restore each across its whole axis, not at the one position a fixture happens to test.** The `line_before_local` latch provided two effects: content exclusion after the marker (deliberately dropped) *and* truncation of the component's `line_end` at the marker (needed, restored only for trailing lines). Measured:

```
d5ba3eb: 💬:q@6 … 🌿:@12 … 📝:@16   →  answer.line_end = 10   (ref survives resubmit)
HEAD:    same transcript             →  answer.line_end = 16   (ref inside 7..16)
```

`chat_respond.lua:1436` runs `be.delete_answer(buf, question.line_end, answer.line_end - 1)` → `nvim_buf_set_lines(buf, 6, 16, …)` → deletes 1-indexed 7..16, including the reference. Driving the real chord (`_branch_inserters(buf,false,true).n()` at line 10 of an answer with text after it) puts the `🌿:` at 12 inside that span. `atlas/chat/inline_branch_links.md:38-43` claims the cost is "fixed at the source … a reference costs exactly its own line wherever it sits"; it is not. Fix sketch: make the resubmit deletion annotation-preserving — collect `🌿:`/`🔒:` lines in `[question.line_end+1, answer.line_end]` and re-emit them after the delete (or delete around them) — and pin it with a test that resubmits an exchange carrying both a mid-answer reference and a mid-answer note, asserting both survive and the reference still resolves.

### 3. Important findings

**`workshop/issues/000214-curate-default-keybindings.md:506,528,536` + `workshop/plans/000214-branch-submit-m3-plan.md:39,159` — the BR-67 renumbering invalidated five cross-references.**
*This is the 2nd finding in family `reference-written-in-unresolvable-form`.* Do not renumber the citations by hand — state the rule: **a cross-reference into an artifact is written in a form that survives that artifact's own renumbering (anchor/heading/date, not an ordinal), or the renumbering edit updates every citation in the same commit.** Consolidating the revisions produced a unique 1-17 sequence, and the M3 Plan rows and the M3 plan file still point at "## Revisions 9 and 10" / "9 and 11" / "9-10". Those slots now hold `<C-g>?` alias rendering, `md_delete_file`'s config key, and master-switch reversibility. The intended targets are 15/16/17. A reader following any of the five lands on an unrelated decision.

### 4. Minor findings

- `lua/parley/helper.lua:117` and `lua/parley/drill_in.lua:346` — new functions spliced into the *middle* of an adjacent function's doc block: `flatten_lines` sits between `---@return string # returns unique uuid` and `_H.uuid`, and `chat_gather_opts` between `chat_boundaries`' prose+`@param` and its `@return`. Both neighbours now carry the wrong annotations. *4th in family `markdown-block-not-separated`* — same rule as BR-67/BR-74, generalised: **a block is inserted between complete blocks, never into the middle of one.**
- `lua/parley/helper.lua:117` — `flatten_lines` is a new exported pure entity with no row in either Core-concepts table; the plan's table also omits `ref_block` and `chat_gather_opts` (the issue's has them). *2nd in family `artifact-missing-from-its-index`* — rule: **a new exported entity is added to the Core-concepts table in the same commit that introduces it.**
- `workshop/issues/…:534-535` still states spacing as `add_block(k, "branch_ref", 1, 1)`; no such block kind exists in `exchange_model.lua`. The code invariant is now correct (`ref_block`), so this is a leftover in the design record, uncovered by the "Superseded" note directly above it.
- `lua/parley/branch_submit.lua:26-31` asserts as current fact that `🌿:` "sets the parser's `line_before_local`" — removed in `b9fc6c8`, one commit later in this same window. `tests/integration/branch_child_spec.lua:409` repeats it.

### 5. Test coverage notes

- Reversion-verified this round: BR-58 (2 red), BR-68 (1 red), BR-69 (1 red). `make test` green end to end, exit 0, lint included.
- The gap that ships the Critical: `annotation_lines_spec.lua:96-106` pins only *"a trailing `🌿:` stays outside the answer's line span"*. There is no fixture with an annotation followed by more answer text, and no test anywhere drives a resubmit over an exchange containing one. This is the same one-sided-axis mistake `workshop/lessons.md` rule 1 was written for this round.
- `branch_submit_spec.lua:126` passes `{}` (truthy) where the signature takes a boolean, and `:131-136` names a branch (`question.content` empty) that `plan_submission` never inspects — both green via the zero-exchanges / marker branches (BR-73, re-raised).

### 6. Architectural notes

- **ARCH-DRY** — flag. `chat_gather_opts`, `seed_question` and `ref_block` are genuine consolidations. But `chat_parser.lua:314-320`'s `annotation_line` re-derives what `kinds[]` at `:557` already holds for every line (`kinds[n] == "local" or kinds[n] == "branch"`), and its comment justifies the duplication with "would cost a call per line" — the call has already been made. See BR-66, re-raised.
- **ARCH-PURE** — pass. `plan_submission`, `seed_question`, `topic_for_selection`, `ref_block`, `flatten_lines` all run in `tests/unit/` with a config table and no plugin (BR-62's lesson applied in `annotation_lines_spec.lua:17-24`). `insert_planned` is the IO shell and reads neighbours from the buffer to feed the pure margin rule — the right seam.
- **ARCH-PURPOSE** — flag, and it is the Critical. Shadow-sweep of the single-source change is otherwise clean: `exporter.lua` and `outline` derive through `chat_parser`/`highlight_structure`, no module re-implements section semantics. But `atlas/chat/inline_branch_links.md:38-43` asserts a purpose ("a reference costs exactly its own line wherever it sits") the diff does not deliver.
- **ARCH-MOCK** — pass. No new external dependency; the `writefile`/`readfile` asymmetry is exercised against the real API in a tmpdir, with a raw-byte read as the conformance oracle.
- **ARCH-CONSTRAINTS** — flag (Minor, BR-71). `<M-i>` is an interactive keypress now doing two full-buffer passes; the redundant `drill_in.parse` was removed, but `M.parse_chat` (uncached) still runs unconditionally at `init.lua:2280` before the gather that decides whether a plan is possible at all, and the adjacent comment claims the opposite ordering.
- **ARCH-SECURE** — pass. `topic` reaches `gsub` only via a function replacement (BR-21 class held); `question` never reaches `gsub` as a replacement; `fnameescape` on the edit. I probed the multi-line-marker label: `sections[n].text` does contain a `\n`, and `topic_for_selection`'s whitespace collapse is what keeps it out of `nvim_buf_set_lines` — load-bearing and worth a word at the call site.
- **ARCH-ORDER** — flag (Minor, BR-72). Good seams for the interleavings that are tested (`pending.identity` injection, `create_child_chat` monkeypatch). But BR-63 moved the point of no return without sweeping past it: `apply_text_edits` and `nvim_buf_set_lines` at `init.lua:2337-2352` sit between the `pcall`'d create and `commit_reference`, so a raise there leaves a child on disk with no reference.

### 7. Plan revision recommendations

- `workshop/plans/000214-branch-submit-m3-plan.md` — a `## Revisions` entry recording that the trailing-annotation trim covers only one position of the axis, and that mid-component annotations remain inside the resubmit delete span; state which milestone owns the fix.
- Same file — replace the ordinal citations at `:39` and `:159` with the revision headings (`### 2026-09-07 — M3 placement reversed…`), and correct `:519-536` in the issue the same way.
- `atlas/chat/inline_branch_links.md:38-43` — withdraw or qualify "a reference costs exactly its own line wherever it sits" until the resubmit path preserves mid-answer annotations.

```findings
dispose:
  - id: BR-58
    disposition: addressed
    note: |
      make_handle anchor + fixtures on both sides of the delta axis; reverting the anchor turns 2 integration tests red.
  - id: BR-59
    disposition: addressed
    note: |
      Plan Core concepts + Task 3 carry corrections, issue Core concepts rewritten, Deviations entry 0 records the removal, ledger rows struck.
  - id: BR-60
    disposition: addressed
    note: |
      Task 7 steps removed with a NOT-DELIVERED note; three ledger rows struck; bracket unified via chat_gather_opts with a no-rebuild test; scope difference stated as deliberate in README, atlas and module header.
  - id: BR-61
    disposition: addressed
    note: |
      gf bullet restored; keybinding_agreement_spec now derives README-key to registry agreement and pins the headline chords in the reverse direction.
  - id: BR-66
    disposition: not-addressed
    note: |
      Predicate still duplicated; the new rationale "would cost a call per line" is contradicted by kinds[] at chat_parser.lua:557, which already holds classify's answer for every line.
  - id: BR-67
    disposition: addressed
    note: |
      Revisions consolidated under one heading, numbering unique 1-17 — but the renumbering broke five cross-references; raised separately.
  - id: BR-68
    disposition: addressed
    note: |
      branch_ref.ref_block owns the margin for both insert paths; reverting it turns the prose-both-sides test red.
  - id: BR-69
    disposition: addressed
    note: |
      refuse_while_pending wraps the n/i/v dispatch table; reverting v turns the every-mode test red.
  - id: BR-70
    disposition: addressed
    note: |
      atlas/chat/drill_in.md now names chat_gather_opts as the owner with both consumers.
  - id: BR-71
    disposition: not-addressed
    note: |
      The redundant drill_in.parse was removed, but M.parse_chat still runs unconditionally at init.lua:2280 before the gather, and the adjacent comment claims the gather is asked first.
  - id: BR-72
    disposition: not-addressed
    note: |
      apply_text_edits and nvim_buf_set_lines at init.lua:2337-2352 remain unguarded between the pcall'd create and commit_reference.
  - id: BR-73
    disposition: not-addressed
    note: |
      Both tests unchanged — branch_submit_spec.lua:126 still passes {} for a boolean, and :131-136 still names a content check plan_submission never performs.
  - id: BR-74
    disposition: not-addressed
    note: |
      The two-line fragment is still stranded, now at issue lines 799-800 after revision 15's body.
findings:
  - id: new
    severity: Critical
    family: merged-path-loses-original-effect
    title: |
      a mid-component 🌿:/🔒: annotation is inside the span a resubmit deletes, so <M-CR> destroys the reference the chord just inserted
    detail: |
      This is the 2nd finding in family `merged-path-loses-original-effect`. Do not
      re-fix the trailing case — the rule is: when a latch is replaced by per-line
      handling, enumerate every effect the latch provided and restore each across
      its whole axis, not at the one position a fixture happens to test. The
      line_before_local latch provided content exclusion (deliberately dropped) AND
      truncation of the component's line_end at the marker; only the trailing half
      of the second was restored by the annotation-aware trim at
      chat_parser.lua:335-352.
      Measured against a base worktree, same transcript: answer.line_end is 10 at
      d5ba3eb and 16 at HEAD for a 🌿: at line 12. chat_respond.lua:1436 calls
      delete_answer(buf, question.line_end, answer.line_end - 1) →
      nvim_buf_set_lines(buf, 6, 16) → deletes 1-indexed 7..16 including the
      reference. Driving the real chord (_branch_inserters(buf,false,true).n() at
      line 10 of an answer with text after it) lands the 🌿: at 12, inside 7..16 —
      so the next resubmit of that exchange orphans the child chat on disk (BR-19)
      and silently deletes any mid-answer 🔒: private note in the same range.
      atlas/chat/inline_branch_links.md:38-43 asserts the opposite. Fix: make the
      resubmit deletion annotation-preserving, pinned by a test that resubmits an
      exchange carrying both a mid-answer reference and a mid-answer note.
  - id: new
    severity: Important
    family: reference-written-in-unresolvable-form
    title: |
      the BR-67 revision renumbering invalidated five cross-references, which now point at unrelated decisions
    detail: |
      This is the 2nd finding in family `reference-written-in-unresolvable-form`.
      Do not renumber the citations by hand — the rule is: a cross-reference into
      an artifact is written in a form that survives that artifact's own
      renumbering (heading or date anchor, not an ordinal), or the renumbering edit
      updates every citation in the same commit.
      Consolidating the revisions produced a unique 1-17 sequence. The issue's M3
      Plan rows at :506, :528 and :536 still say "## Revisions 9 and 10" / "9 and
      11", and workshop/plans/000214-branch-submit-m3-plan.md:39 and :159 say
      "## Revisions 9-10". Slots 9/10/11 now hold alias rendering in <C-g>?,
      md_delete_file's config key, and master-switch reversibility. The intended
      targets are 15/16/17.
  - id: new
    severity: Minor
    family: markdown-block-not-separated
    title: |
      two new functions were spliced into the middle of an adjacent function's doc-comment block
    detail: |
      This is the 4th finding in family `markdown-block-not-separated`. Do not fix
      the two sites — the rule generalises past markdown: a block is inserted
      BETWEEN complete blocks, never into the middle of one.
      helper.lua:117 puts flatten_lines between "---@return string # returns unique
      uuid" and _H.uuid, so uuid loses its annotation and flatten_lines gains a
      bogus second @return. drill_in.lua:346 puts chat_gather_opts between
      chat_boundaries' description plus @param cfg and its @return string[], so
      chat_boundaries is left with only a return type and chat_gather_opts inherits
      prose about the anchor scan that describes its neighbour.
  - id: new
    severity: Minor
    family: artifact-missing-from-its-index
    title: |
      helper.flatten_lines shipped as a new exported pure entity with no Core-concepts row
    detail: |
      This is the 2nd finding in family `artifact-missing-from-its-index`. The rule
      covering both: a new exported entity is added to the Core-concepts table that
      enumerates its kind, in the same commit that introduces it.
      flatten_lines is new, exported, unit-tested and guarded by an arch spec, but
      appears in neither the issue's nor the plan's Core concepts. The plan's table
      also omits ref_block and chat_gather_opts, which the issue's table does carry
      — so the two tables disagree about what M3 delivered.
```

---

## Re-review — 2026-09-07T19:21:28-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | d5ba3ebca28f42a93cf95ed132bd695c12f29c50..87ecc53bf37dc58c190bde22725a9cd782f488d7 |
| command | sdlc milestone-close --issue 214 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-07T19:21:28-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The BR-75 fix is real and genuinely pinned — I reverted `delete_answer` to a plain range delete in the working tree and three assertions in `tests/unit/annotation_lines_spec.lua` went red, so the claim survives the "test fails without it" check. `make test` is green across 200 spec files and `luacheck` is clean over 356. But the fix covers the *full-line* `🌿:`/`🔒:` axis only, and the enumerable sibling is still in the tree: an **inline** `[🌿:…](child.md)` — the anchor the M3 visual chord creates by design, inside an answer — is still destroyed by the next `<M-CR>`, orphaning a child that is on disk. I drove the real chord (`_branch_inserters(buf,false,true).v()`) on a real chat buffer, watched the parent get written and the child land in `chat_dir`, then ran the resubmit's own `delete_answer` and the only pointer was gone. That is BR-75's consequence, one position over on the same axis, and the commit that fixed BR-75 states the covering rule ("every position is covered at once rather than one at a time") without sweeping to it. Five prior findings are also still open unchanged, including BR-77 (which has a third instance introduced by this round's own commit) and BR-71/BR-72/BR-73/BR-74. Separately: the pinned head `87ecc53` is **two commits behind the working tree** (`ddb5614`) — `3d8ab7b` and `ddb5614` are unreviewed by this gate.

## 1. Strengths

- **The fix is at the right altitude.** Moving the rule from "keep annotations out of spans" (parser boundary) to "a resubmit replaces the model's output, and an annotation is not the model's output" (`lua/parley/buffer_edit.lua:113`) is the correct restatement — it makes `delete_answer` the obvious home and covers leading/middle/trailing in one place instead of one position at a time. `ARCH-PURPOSE` credit for finding the general statement.
- **Reversion-verified, not asserted.** `tests/unit/annotation_lines_spec.lua:127-186` drives `delete_answer` against a real buffer for mid-answer branch, mid-answer note, several-in-order, and the nothing-to-keep case. I confirmed independently that reverting the fix turns 3 of them red.
- **BR-69's sweep was done at the class, not the site.** `refuse_while_pending` wraps the whole dispatch table (`lua/parley/init.lua:2470-2492`) and `tests/integration/branch_child_spec.lua:775` iterates all three modes rather than re-testing the one that had the guard. This is the pattern the other repeats are missing.
- **The parser change is consistent with the fence machinery.** I scanned 5,243 lines across 20 fixture and real transcript files comparing `annotation.is_annotation` against the parser's fence-aware `kinds[]`: **zero disagreements**. Column-0 markers bound tool bodies and indented ones don't match the prefix, so the two classifiers cannot diverge on real data.
- **The exchange model stays coherent.** I checked `from_parsed_chat` with and without a trailing `🌿:`; the ref becomes its own `text` block and every downstream `block_start` still lands on the right buffer line. The trailing-trim does not desynchronize the model.

## 2. Critical findings

**C1 — an inline `[🌿:…](child.md)` inside an answer is destroyed by a resubmit, orphaning the child** (`lua/parley/buffer_edit.lua:119-123`)

*This is the 3rd finding in family `merged-path-loses-original-effect`.* Do not fix the inline case as an instance. State the rule: **the survivor set of a resubmit is every user-authored pointer to a durable artifact inside the deleted span, derived from the parser's own branch/annotation extraction — not from a line-prefix test.** `is_annotation` answers "does this line *start* with a prefix", which is a strictly narrower question than "does this line carry a reference".

Measured end-to-end on a real chat buffer: `<M-i>` in visual mode over text inside an answer produces `the answer talks about m[🌿:onads ](2026-09-07.19-18-20.725.md)here`, creates the child on disk, and `:write`s the parent. The parser reports `branches=1`. `delete_answer(buf, question.line_end, answer.line_end - 1)` — the exact call at `lua/parley/chat_respond.lua:1436` — then leaves the buffer at `💬: first question` with the link gone and the child unreachable. Identical consequence to BR-75, same milestone, documented path (`README.md`, `atlas/chat/inline_branch_links.md` both list the visual case first).

Fix sketch: extract a pure `annotation.survivors(lines, cfg) -> string[]` that keeps (a) lines beginning with a configured annotation prefix and (b) lines containing an inline branch link, reusing `chat_parser.extract_inline_branch_links` rather than a second matcher; have `delete_answer` call it. Pin with a test that resubmits an exchange carrying a full-line `🌿:`, a full-line `🔒:`, **and** an inline `[🌿:…](f)`, and assert all three survive.

## 3. Important findings

**I1 — `annotation.is_annotation` silently substitutes the shipped prefixes for a missing live config, which is the shape `is_partition` exists to forbid** (`lua/parley/annotation.lua:16-28`)

`cfg = cfg or {}` then `cfg.chat_branch_prefix or M.DEFAULTS.branch` is exactly what `lua/parley/highlight_structure.lua:180-187` refuses, in a comment naming the incident it cost: *"No `patterns or M.patterns()` default. Silently falling back to the shipped prefixes is exactly BR-2: containment looked fixed and did nothing for anyone with a custom `chat_user_prefix`, at two call sites, twice. An assert makes that state unrepresentable instead of auditable."* This is a **new internal module** whose surface downstream code will consume, and it ships the banned affordance as its documented default. `buffer_edit.delete_answer:117` reaches it via `require("parley").config`, which is only populated at `init.lua:540` inside `setup()` — so the fallback is live surface, not dead code. `ARCH-SECURE` (input turned into a value by fabrication rather than by parse) and `ARCH-DRY` (`M.DEFAULTS` is a third hardcoded copy of `config.lua:283,285`).

Also: the parser's comment at `chat_parser.lua:307-310` claims `parley.annotation` "owns that question for the whole codebase". It does not — `highlight_structure.classify:98-99` and `is_partition:196-197` still answer it from their own compiled patterns. Either the new module derives from `highlight_structure.patterns(config)` (which `parse_chat` already has in scope as `decoration_patterns`), or the comment should stop claiming exclusivity.

Fix sketch: `assert(type(cfg) == "table" and cfg.chat_branch_prefix, ...)` or take compiled `patterns` like `is_partition` does; delete `M.DEFAULTS`.

## 4. Minor findings

- **M1** — `lua/parley/buffer_edit.lua:96` still carries the old first doc line (`--- Delete an answer region by inclusive 0-indexed line range.`) directly above the new block, so `delete_answer` has two opening summaries. This is a **third** instance of BR-77's rule in the same tree.
- **M2** — `lua/parley/branch_submit.lua:26-31` and `tests/integration/branch_child_spec.lua:408-412` both still assert `🌿: sets the parser's line_before_local`, a mechanism deleted by `b9fc6c8` **inside this window**. `line_before_local` no longer exists in `chat_parser.lua`. *6th finding in family `stale-comment-after-move`* — state the rule: **a commit that removes a mechanism greps for its name and updates or deletes every prose reference in the same commit** (`grep -rn line_before_local lua/ tests/` returns these two live claims plus four historical ones).
- **M3** — `lua/parley/annotation.lua` appears in no `atlas/traceability.yaml` entry (`branch_submit.lua` was added; this one was not), and `tests/unit/annotation_lines_spec.lua` is filed under `ui/keybindings:tests` (:704) while `atlas/chat/parsing.md` cites it by name as the spec asserting the parsing contract — so `make test-changed` on `atlas/chat/parsing.md` will not run it. *3rd finding in family `artifact-missing-from-its-index`* — rule: **a new module and its spec are routed under the atlas doc whose contract they implement, in the commit that adds them.**
- **M4** — `workshop/plans/000214-branch-submit-m3-plan.md:330` ticks `sdlc milestone-close --issue 214 --milestone M3` before the close has happened; :322 ticks "the measured reason the ref follows `📝:`" for docs that now say the opposite; the "Open risks" block still describes case 2b's "last exchange", removed by the narrowing. *3rd finding in family `plan-not-revised-after-decision-change`* — rule: **when a decision is superseded, the same edit sweeps every step, risk and checkbox that depends on it; a checkbox is ticked by the action, never in advance.**
- **M5** — `buffer_edit.lua:108-109` claims survivors stay "attached to the exchange it annotates rather than drifting to the end". I ran the composed flow (`delete_answer` → reparse → `from_parsed_chat` → `block_start` → the blank-cleanup and `insert_lines_at` at `chat_respond.lua:1550-1578`): the regenerated answer shell is inserted *above* the survivors, so the reference does land at the end of the new answer. No test exercises the composed transition. *9th finding in family `docs-assert-unverified-behavior`* — rule: **a sentence describing a composed flow is backed by a test that runs that flow, or it is narrowed to what the function itself does.**
- **M6 (outside the pinned window)** — `workshop/000214-smoke.md`, added in `ddb5614`, sits at the `workshop/` root, which names no datatype directory. *3rd finding in family `scratch-artifact-swept-into-commit`* — rule: **a workshop artifact lives in the subdirectory its datatype names; nothing lands at `workshop/` root** (enforceable as a guard).

## 5. Test coverage notes

- The BR-75 assertions are good and reversion-verified. What they cannot see is the **composed** resubmit: every test calls `delete_answer` directly, including the "end-to-end" one at `branch_child_spec.lua:1024-1032`, which drives the real chord and then hand-calls the deletion. The gap that let C1 through is the same one: no fixture puts an *inline* link in the deleted span.
- `tests/unit/branch_submit_spec.lua:125-135` — both declining tests pass through branches other than the ones they name (see BR-73 disposition).
- The arch guard at `tests/arch/single_source_sweeps_spec.lua:653-680` matches `^%+function M%.…` / `^%+M%.… = …`; `_H.flatten_lines = function` matches neither, which is why BR-78's entity was invisible to it. Worth widening to the `_H.` idiom, since `helper.lua` is where composed-line helpers land.

## 6. Architectural notes

- **ARCH-DRY** — flag (I1): three hardcoded copies of the shipped prefixes and two classifiers answering the same line-kind question.
- **ARCH-PURE** — mostly pass. `branch_submit`, `ref_block`, `topic_for_selection`, `flatten_lines`, `is_annotation` are pure and unit-tested without IO. Flag: the *survivor decision* inside `delete_answer` is pure logic living inside the IO shell, testable only through `nvim_buf_*`. Extracting it is also the natural home for C1's fix.
- **ARCH-PURPOSE** — flag (C1): the class named by the fix's own commit message is not swept.
- **ARCH-MOCK** — pass, with a note. No new external binary or service. The `flatten_lines` guard is honestly labelled as a source-level assertion because `readfile` round-trips the NUL and no behavioural test can distinguish the fix from its absence — that is the right call, stated rather than hidden.
- **ARCH-CONSTRAINTS** — flag (BR-71): the `<M-i>` keystroke path still does two full-buffer passes with no declared envelope, and the comment at `init.lua:2283-2287` asserts the ordering the code does not have.
- **ARCH-SECURE** — flag (I1). Otherwise pass: `flatten_lines` is a genuine input-integrity fix, and `topic_for_selection` collapsing whitespace keeps a multi-line selection from breaking the `🌿:` line format.
- **ARCH-ORDER** — flag (BR-72): the point of no return moved but the effects after it are unguarded; `insert_inline` (`init.lua:2459-2462`) mutates the buffer before an entirely unguarded `create_child_if_owned`, the same shape one function over. Pass on the pending-response event, which is enumerated and tested across all three modes.

## 7. Plan revision recommendations

- `workshop/plans/000214-branch-submit-m3-plan.md` — append a `## Revisions` entry recording that Task 9's close checkbox was ticked before the close, that Task 8 Step 1's "measured reason the ref follows `📝:`" no longer describes the shipped docs, and that the Open-risks entry on case 2b describes a case the narrowing removed.
- `workshop/issues/000214-curate-default-keybindings.md` — add `delete_answer` (`lua/parley/buffer_edit.lua`, modified) to the **Integration points** table. The plan's design record now carries it and the issue's delivered record does not, which is BR-78's disagreement in the opposite direction.
- `workshop/issues/000214-curate-default-keybindings.md:807-808` — the stranded fragment BR-74 named is still dangling at the end of the "single-line annotations" revision block.

```findings
dispose:
  - id: BR-66
    disposition: addressed
    note: |
      inline re-match retired; single owner exists, though outside highlight_structure — see I1.
  - id: BR-71
    disposition: not-addressed
    note: |
      init.lua:2281 still parses before the gather at :2289; the comment claims the reverse ordering.
  - id: BR-72
    disposition: not-addressed
    note: |
      init.lua:2340 and :2351 remain unguarded after the pcall'd create at :2317; insert_inline is a second site.
  - id: BR-73
    disposition: not-addressed
    note: |
      branch_submit_spec.lua:125 still passes `{}` for a boolean; :131 still names a content check plan_submission never makes.
  - id: BR-74
    disposition: not-addressed
    note: |
      numbering is now unique 4-17 and all under Revisions, but the two-line fragment at issue :807-808 is still dangling.
  - id: BR-75
    disposition: addressed
    note: |
      verified by reversion — three assertions in annotation_lines_spec go red without the fix. Class incomplete: see C1.
  - id: BR-76
    disposition: addressed
    note: |
      citations now use dated headings and the section states the rule; no ordinal citations remain in issue or plan.
  - id: BR-77
    disposition: not-addressed
    note: |
      helper.lua:116 and drill_in.lua:345 unchanged; this round added a third site at buffer_edit.lua:96.
  - id: BR-78
    disposition: addressed
    note: |
      plan table synced with (as built) rows and the two records labelled; delete_answer is still absent from the issue's table.
findings:
  - id: new
    severity: Critical
    family: merged-path-loses-original-effect
    title: |
      an inline [🌿:…](child.md) inside an answer is still destroyed by a resubmit, orphaning the child
    detail: |
      This is the 3rd finding in family `merged-path-loses-original-effect`. Do not fix
      the inline case as an instance — the rule is: the survivor set of a resubmit is
      every user-authored pointer to a durable artifact inside the deleted span, derived
      from the parser's own branch/annotation extraction rather than from a line-prefix
      test. `is_annotation` answers "does this line START with a prefix", which is
      strictly narrower than "does this line carry a reference".
      Measured end-to-end: driving the real visual chord
      (_branch_inserters(buf,false,true).v()) over text inside an answer in a chat buffer
      produces `the answer talks about m[🌿:onads ](2026-09-07.19-18-20.725.md)here`,
      creates the child on disk and writes the parent; the parser reports branches=1.
      buffer_edit.delete_answer(buf, question.line_end, answer.line_end - 1) — the exact
      call at chat_respond.lua:1436 — then leaves the buffer at `💬: first question` with
      the link gone and the child unreachable. Identical consequence to BR-75, one
      position over on the same axis, on a path README.md and
      atlas/chat/inline_branch_links.md both document first.
      Fix: extract a pure `annotation.survivors(lines, cfg)` that keeps annotation-prefixed
      lines AND lines carrying an inline branch link (reusing
      chat_parser.extract_inline_branch_links, not a second matcher); pin with a resubmit
      test carrying a full-line 🌿:, a full-line 🔒: and an inline [🌿:…](f) at once.
  - id: new
    severity: Important
    family: silent-fallback-to-shipped-default
    title: |
      annotation.is_annotation fabricates the shipped prefixes for a missing live config, the shape is_partition exists to forbid
    detail: |
      lua/parley/annotation.lua:16-28 does `cfg = cfg or {}` then
      `cfg.chat_branch_prefix or M.DEFAULTS.branch`. highlight_structure.is_partition
      (:180-187) refuses exactly this in a comment naming the incident it cost: "No
      `patterns or M.patterns()` default. Silently falling back to the shipped prefixes is
      exactly BR-2 ... at two call sites, twice. An assert makes that state
      unrepresentable instead of auditable." annotation.lua is a NEW internal module whose
      surface downstream code will consume, and it ships the banned affordance as its
      documented default; buffer_edit.delete_answer:117 reaches it through
      `require("parley").config`, populated only inside setup() at init.lua:540, so the
      fallback is live surface. ARCH-SECURE (a value fabricated rather than parsed) and
      ARCH-DRY (M.DEFAULTS is a third hardcoded copy of config.lua:283,285).
      Related: chat_parser.lua:307-310 claims parley.annotation "owns that question for
      the whole codebase" while highlight_structure.classify:98-99 and is_partition:196-197
      still answer it independently — and parse_chat already holds the compiled
      `decoration_patterns` it could have asked.
      Fix: assert a live config (or take compiled `patterns` like is_partition does) and
      delete M.DEFAULTS.
  - id: new
    severity: Minor
    family: stale-comment-after-move
    title: |
      two live comments still assert the line_before_local latch this window deleted
    detail: |
      This is the 6th finding in family `stale-comment-after-move`. Do not fix the two
      sites — the rule is: a commit that removes a mechanism greps for its name and
      updates or deletes every prose reference in the same commit.
      branch_submit.lua:26-31 ("The cost is measured and real: 🌿: sets the parser's
      line_before_local ... so answer text AFTER a mid-answer reference is excluded from
      the LLM context and the exchange model truncates that exchange") and
      branch_child_spec.lua:408-412 both state a behaviour b9fc6c8 removed INSIDE this
      window, and which README.md and atlas/chat/parsing.md now describe the opposite way.
      `grep -rn line_before_local lua/ tests/` returns these two live claims plus four
      correctly-historical ones.
  - id: new
    severity: Minor
    family: artifact-missing-from-its-index
    title: |
      annotation.lua is in no traceability entry, and its spec is filed under the atlas doc it does not verify
    detail: |
      This is the 3rd finding in family `artifact-missing-from-its-index`. Do not fix the
      two rows — the rule is: a new module and its spec are routed under the atlas doc
      whose contract they implement, in the commit that adds them.
      lua/parley/annotation.lua appears nowhere in atlas/traceability.yaml (branch_submit.lua
      was added in the same window; this one was not) and nowhere in atlas/ at all.
      tests/unit/annotation_lines_spec.lua is filed under ui/keybindings:tests (:704) while
      atlas/chat/parsing.md cites it by name as the spec asserting the parsing contract —
      so `make test-changed` on atlas/chat/parsing.md does not run it. The Core-concepts
      arch guard cannot catch either, because it only matches `+function M.x(` and
      `+M.x = <rhs>` and misses the `_H.x = function` helper idiom that flatten_lines uses.
  - id: new
    severity: Minor
    family: plan-not-revised-after-decision-change
    title: |
      the M3 plan ticks its own milestone-close, and two steps still describe superseded decisions
    detail: |
      This is the 3rd finding in family `plan-not-revised-after-decision-change`. Do not
      fix the three rows — the rule is: when a decision is superseded, the same edit
      sweeps every step, risk and checkbox that depends on it; and a checkbox is ticked by
      the action, never in advance.
      workshop/plans/000214-branch-submit-m3-plan.md:330 ticks `sdlc milestone-close
      --issue 214 --milestone M3` although this review IS that gate and the issue's `## Log`
      carries no M3 entry. :322 ticks "including the measured reason the ref follows 📝:"
      for docs that now say placement is the cursor. The "Open risks" block still names
      case 2b's "last exchange", which the narrowing removed.
  - id: new
    severity: Minor
    family: docs-assert-unverified-behavior
    title: |
      delete_answer's doc claims survivors do not drift to the end; in the composed resubmit they do
    detail: |
      This is the 9th finding in family `docs-assert-unverified-behavior`. Do not fix the
      sentence — the rule is: a sentence describing a COMPOSED flow is backed by a test
      that runs that flow, or it is narrowed to what the function itself does.
      buffer_edit.lua:108-109 says survivors are re-inserted "at the deletion point, so the
      reference stays attached to the exchange it annotates rather than drifting to the
      end". Running the real sequence (delete_answer -> reparse -> from_parsed_chat ->
      block_start -> the blank cleanup and insert_lines_at at chat_respond.lua:1550-1578)
      inserts the regenerated answer shell ABOVE the survivors, so a mid-answer reference
      lands at the end of the new answer. Benign, but unasserted: every test calls
      delete_answer directly, including the one named "end-to-end"
      (branch_child_spec.lua:1024).
  - id: new
    severity: Minor
    family: scratch-artifact-swept-into-commit
    title: |
      workshop/000214-smoke.md sits at the workshop root, which names no datatype
    detail: |
      This is the 3rd finding in family `scratch-artifact-swept-into-commit`. Do not just
      move the file — the rule is: a workshop artifact lives in the subdirectory its
      datatype names (issues/, plans/, parley/, pensive/, projects/, targets/, vision/);
      nothing lands at workshop/ root. This is guard-enforceable.
      NOTE: this arrived in ddb5614, which is OUTSIDE the pinned review window
      (d5ba3eb..87ecc53). The working tree is two commits ahead of the pinned head —
      3d8ab7b and ddb5614 have not been reviewed by any gate. Re-pin or review them
      before recording the M3 verdict.
```
