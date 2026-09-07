---
gate: plan-quality
issue: 214
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-06T07:58:14-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Important
          title: Config `shortcut` replaces `default_key` wholesale, so M1's chord edits are inert for `chat_prune` and M2 can silently revoke M1's chords
          detail: '`keybinding_registry.lua:990` returns `as_list(cfg_val.shortcut) or as_list(entry.default_key)` — no merge. `chat_prune` is config-resolved (`config.lua:349` supplies `<C-g>b`), so adding a key list to its registry entry changes nothing; and when M2 gives `branch_ref` a `config_key`, a single-string config default silently drops M1''s `<M-S-CR>`/`<M-i>`. State which artifact carries the list in M1, and require the ten new M2 config defaults to carry the full resolved list.'
          family: config-shadows-default-key
          round: 1
        - id: PQ-2
          severity: Important
          title: M1 does not say when the n/i path creates the child, and the topic does not exist at keypress
          detail: "`chat_insert_branch_ref` (`init.lua:2104-2116`) inserts an empty-tailed ref and `startinsert!`s so the topic is typed afterward, while `create_child_chat` (`init.lua:4513`) bakes the topic into the header and seeds the `\U0001F4AC:` question from it. Name the triggering event and what happens on the abandonment cases the caller cannot block (`<Esc>` before typing, undo of the inserted line, buffer closed) — each currently leaves an orphan file. Also state which buffer holds focus after \"open\", since `create_child_chat` only writes the file today and opening it collides with the parent-line `startinsert!`."
          family: branch-ref-creation-ordering
          round: 1
        - id: PQ-3
          severity: Important
          title: M1 fixes the chat branch paths and leaves the identical markdown twins untouched
          detail: '`md_insert_branch_ref` (`init.lua:2427-2438`) has the same missing `create_child_chat`, and `md_insert_inline_branch_ref` (`:2440`) is a near-copy of `chat_insert_inline_branch_ref` (`:2118`) differing only in `:t` vs `:p`. `format_branch_ref` (`:2416`) already emits exactly what the chat path builds inline. Name the shared helper both families collapse into and sweep both in M1 (ARCH-DRY, ARCH-PURPOSE).'
          family: fix-the-class-not-the-site
          round: 1
        - id: PQ-4
          severity: Important
          title: '"Assert help/reality agreement in both directions" contradicts the same plan''s decision to keep six core keys off-registry'
          detail: Done-when says no binding exists that `<C-g>?` cannot show, while an M2 row deliberately leaves `u`, `<C-r>`, `*`, `#`, `g*`, `g#` (plus `interview.lua:85` and, when opted in, `spell.lua:168`) outside the registry. The reality direction fails by construction. Require a machine-checkable exemption list rather than prose, and name the seam — help is `_keybinding_help_lines` (registry+config), reality means `nvim_get_keymap`/`nvim_buf_get_keymap`.
          family: off-registry-exemption-contract
          round: 1
        - id: PQ-5
          severity: Important
          title: 'Done-when requires the ariadne `<C-y>`/`<C-j>` split that the Plan explicitly defers to after #212'
          detail: '"a fresh install claims no `<leader>` key and no `<C-y>`/`<C-j>` key in any context" cannot be certified at close, since the Plan defers the ariadne core/opt-in split and #212 is still `status: open`. Split the criterion so the `<leader>` half stays in M2 and the ariadne half moves out with a named owner.'
          family: done-when-overstates-plan
          round: 1
        - id: PQ-6
          severity: Minor
          title: No test strategy named for `resolve_keys` or the `spell.attach` gate, the two functions whose semantics M2 changes
          detail: 'One strategy line each: `resolve_keys` against config values that are a string, a list, an empty string, and a table with no `shortcut`; `spell.attach` against `typeahead` nil / false / true crossed with a partial `chat_spell = { enable = true }` and with `prompt_buf_type`. The M2 `config_key` assertion should tighten the existing check at `tests/unit/keybindings_spec.lua:217-229` rather than land beside it.'
          family: test-strategy-per-risky-function
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-06T08:01:57-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: not-addressed
          note: Ordering note added, but the M1 config shape is a bare list where resolve_keys reads cfg_val.shortcut, and the rule for M2's nine new config_keys is still unstated.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Triggering event named (create immediately, empty topic) and focus resolved to the child; abandonment now degrades to the same shape as an abandoned <C-g>c chat.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Class widened to all four functions including the markdown twins, swept in M1 via one shared helper.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: Criterion scoped to registry-derived bindings with the six fall-through keys as a named closed allowance list the assertion checks does not grow.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: 'The <C-y>/<C-j> half moved out with #212 named as owner; the <leader> half stays in M2.'
          round: 2
        - id: PQ-6
          disposition: addressed
          note: One strategy line each for resolve_keys and spell.attach, plus tightening the existing assertion rather than duplicating it.
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-06T08:04:00-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Plan names config.lua as the list-carrying artifact, moves branch_ref's config_key into M1, and adds a mechanical superset guard covering the whole shrink class.
          round: 3
      blocked: false
    - "n": 4
      timestamp: "2026-09-07T16:28:00-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Shipped list lives in config.lua:397; registry comment records why.
          round: 4
        - id: PQ-2
          disposition: addressed
          note: Creation timing and the "?" topic sentinel are written out at init.lua:2287-2306.
          round: 4
        - id: PQ-3
          disposition: addressed
          note: All four functions collapsed into branch_inserters at init.lua:2206.
          round: 4
        - id: PQ-4
          disposition: addressed
          note: Done-when now names the closed allowance list instead of asserting registration.
          round: 4
        - id: PQ-5
          disposition: addressed
          note: The ariadne half of the fresh-install criterion moved out with an owner.
          round: 4
        - id: PQ-6
          disposition: addressed
          note: M2 carries strategy lines for both resolve_keys and spell.attach.
          round: 4
      findings:
        - id: PQ-7
          severity: Important
          title: M3 specifies the chat behaviour of <M-S-CR> and leaves the markdown half of the same chord undefined
          detail: |-
            This is the 2nd finding in family `fix-the-class-not-the-site`; PQ-3 was
            the same rule on M1. Do not patch M3's table alone. The governing rule
            already exists in this issue's `## Revisions` section 3 — "parley commits a
            reference only in a file it owns" — and the plan must state it as the
            column that every row of the M3 table is keyed on, so the next branch-chord
            row cannot omit it either. Measured prevalence: 2 rounds, both on this
            chord, both omitting the markdown twin.
            Failure scenario, verified against the tree: `branch_ref` is
            `scope = "parley_buffer"` (keybinding_registry.lua:484) and init.lua:2702
            builds `md_branch = branch_inserters(buf, true, false)`, wired at :2720 in
            n/i/v; `chat_drill_in` is registered on the same buffers at :2728. So a user
            presses `<M-q>` then `<M-S-CR>` in an ordinary markdown document: contexts 2a
            and 2b apply, but there is no exchange model, no `append_pos`, and no
            colon-summary to land the ref after, and M3's governing sentence resolves to
            `review_next` (keybinding_registry.lua:756, modes n/i only) rather than a
            submission. An implementer following the table literally either crashes on
            the exchange model or silently reintroduces the orphan-child defect M1's
            BR-28 closed.
          family: fix-the-class-not-the-site
          round: 4
        - id: PQ-8
          severity: Important
          title: M3's STRIP decision destroys parent content but the plan does not order strip against child creation or say what a failed create leaves behind
          detail: |-
            This is the 2nd finding in family `branch-ref-creation-ordering`; PQ-2 was
            the same rule on M1's no-selection path. Do not answer for this row alone —
            state the rule the family needs: any M3 row that mutates the parent before
            the child is durable must name the order of strip / create / commit and the
            state the buffer is left in when a later step fails. Measured prevalence: 2
            rounds, both on the create-child sequence.
            Failure scenario: `insert_inline` (init.lua:2308-2333) mutates the buffer,
            then calls `create_child_if_owned`, which calls `M.create_child_chat`
            unguarded (init.lua:2229-2233), then `commit_reference`, whose failure only
            warns. Under M3 the pre-mutation is the user's `<M-q>` markers removed from
            the parent. If `create_child_chat` raises (chat_dir unwritable, disk full)
            after the strip, the quotes are gone from the parent and were never written
            to a child — unrecoverable, because the markers were the only record of the
            selection. ARCH-ORDER at-plan: name which of cancel / rollback governs, and
            whether the strip is deferred until the child exists on disk.
          family: branch-ref-creation-ordering
          round: 4
        - id: PQ-9
          severity: Important
          title: M3 names no functions to unit-test and carries no strategy line, for the milestone the plan itself calls the Critical-producing class
          detail: |-
            This is the 2nd finding in family `test-strategy-per-risky-function`; PQ-6
            was the same rule on M2. Do not add one line for one row — state the rule:
            every unchecked Plan row that changes behaviour names the functions it
            changes and carries one adversarial-input line per risky function, the same
            shape M1's "Test: resolve_keys returns all three" and M2's `spell.attach`
            line already use. Measured prevalence: 2 rounds, M2 then M3.
            As written M3 names `gather_and_strip` (drill_in.lua:505) as reused and
            `add_block` / `append_pos` as the placement API, but never says which new
            function is pure, which is the IO seam, or what is under test — so the
            milestone is un-startable without the implementer inventing the split
            (ARCH-PURE at-plan). The adversarial classes are already visible from the
            table: an exchange whose answer has no summary block, markers spread across
            two exchanges, an empty or whitespace-only selection, and a cursor position
            matching none of the five rows.
          family: test-strategy-per-risky-function
          round: 4
        - id: PQ-10
          severity: Minor
          title: Done-when has no acceptance criterion for M3, and M3 row 1 silently changes the child seed M1 shipped
          detail: |-
            All six Done-when clauses are keybinding-curation clauses; none of them is
            satisfied or falsified by M3's behaviour, so the M3 boundary has nothing to
            certify against. Separately, row 1 states the child is seeded
            `tell me more about "<sel>"` where the shipped path seeds `topic .. "?"`
            (init.lua:2325) — a change to closed-milestone behaviour presented in the
            column that otherwise describes what exists.
          family: done-when-overstates-plan
          round: 4
      blocked: false
content_hash: fd3d6a0287896276408b6aec6dbb848ea3700a16b76ec4b5f97ae104fdaed41d
---

# Gate ledger — parley.nvim#214 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-06T07:58:14-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Important] `config-shadows-default-key` Config `shortcut` replaces `default_key` wholesale, so M1's chord edits are inert for `chat_prune` and M2 can silently revoke M1's chords
  `keybinding_registry.lua:990` returns `as_list(cfg_val.shortcut) or as_list(entry.default_key)` — no merge. `chat_prune` is config-resolved (`config.lua:349` supplies `<C-g>b`), so adding a key list to its registry entry changes nothing; and when M2 gives `branch_ref` a `config_key`, a single-string config default silently drops M1's `<M-S-CR>`/`<M-i>`. State which artifact carries the list in M1, and require the ten new M2 config defaults to carry the full resolved list.
- **PQ-2** [Important] `branch-ref-creation-ordering` M1 does not say when the n/i path creates the child, and the topic does not exist at keypress
  `chat_insert_branch_ref` (`init.lua:2104-2116`) inserts an empty-tailed ref and `startinsert!`s so the topic is typed afterward, while `create_child_chat` (`init.lua:4513`) bakes the topic into the header and seeds the `💬:` question from it. Name the triggering event and what happens on the abandonment cases the caller cannot block (`<Esc>` before typing, undo of the inserted line, buffer closed) — each currently leaves an orphan file. Also state which buffer holds focus after "open", since `create_child_chat` only writes the file today and opening it collides with the parent-line `startinsert!`.
- **PQ-3** [Important] `fix-the-class-not-the-site` M1 fixes the chat branch paths and leaves the identical markdown twins untouched
  `md_insert_branch_ref` (`init.lua:2427-2438`) has the same missing `create_child_chat`, and `md_insert_inline_branch_ref` (`:2440`) is a near-copy of `chat_insert_inline_branch_ref` (`:2118`) differing only in `:t` vs `:p`. `format_branch_ref` (`:2416`) already emits exactly what the chat path builds inline. Name the shared helper both families collapse into and sweep both in M1 (ARCH-DRY, ARCH-PURPOSE).
- **PQ-4** [Important] `off-registry-exemption-contract` "Assert help/reality agreement in both directions" contradicts the same plan's decision to keep six core keys off-registry
  Done-when says no binding exists that `<C-g>?` cannot show, while an M2 row deliberately leaves `u`, `<C-r>`, `*`, `#`, `g*`, `g#` (plus `interview.lua:85` and, when opted in, `spell.lua:168`) outside the registry. The reality direction fails by construction. Require a machine-checkable exemption list rather than prose, and name the seam — help is `_keybinding_help_lines` (registry+config), reality means `nvim_get_keymap`/`nvim_buf_get_keymap`.
- **PQ-5** [Important] `done-when-overstates-plan` Done-when requires the ariadne `<C-y>`/`<C-j>` split that the Plan explicitly defers to after #212
  "a fresh install claims no `<leader>` key and no `<C-y>`/`<C-j>` key in any context" cannot be certified at close, since the Plan defers the ariadne core/opt-in split and #212 is still `status: open`. Split the criterion so the `<leader>` half stays in M2 and the ariadne half moves out with a named owner.
- **PQ-6** [Minor] `test-strategy-per-risky-function` No test strategy named for `resolve_keys` or the `spell.attach` gate, the two functions whose semantics M2 changes
  One strategy line each: `resolve_keys` against config values that are a string, a list, an empty string, and a table with no `shortcut`; `spell.attach` against `typeahead` nil / false / true crossed with a partial `chat_spell = { enable = true }` and with `prompt_buf_type`. The M2 `config_key` assertion should tighten the existing check at `tests/unit/keybindings_spec.lua:217-229` rather than land beside it.

## Round 2 — 2026-09-06T08:01:57-07:00 (claude) — BLOCKED

### Disposed

- PQ-1 — not-addressed — Ordering note added, but the M1 config shape is a bare list where resolve_keys reads cfg_val.shortcut, and the rule for M2's nine new config_keys is still unstated.
- PQ-2 — addressed — Triggering event named (create immediately, empty topic) and focus resolved to the child; abandonment now degrades to the same shape as an abandoned <C-g>c chat.
- PQ-3 — addressed — Class widened to all four functions including the markdown twins, swept in M1 via one shared helper.
- PQ-4 — addressed — Criterion scoped to registry-derived bindings with the six fall-through keys as a named closed allowance list the assertion checks does not grow.
- PQ-5 — addressed — The <C-y>/<C-j> half moved out with #212 named as owner; the <leader> half stays in M2.
- PQ-6 — addressed — One strategy line each for resolve_keys and spell.attach, plus tightening the existing assertion rather than duplicating it.

## Round 3 — 2026-09-06T08:04:00-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Plan names config.lua as the list-carrying artifact, moves branch_ref's config_key into M1, and adds a mechanical superset guard covering the whole shrink class.

## Round 4 — 2026-09-07T16:28:00-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Shipped list lives in config.lua:397; registry comment records why.
- PQ-2 — addressed — Creation timing and the "?" topic sentinel are written out at init.lua:2287-2306.
- PQ-3 — addressed — All four functions collapsed into branch_inserters at init.lua:2206.
- PQ-4 — addressed — Done-when now names the closed allowance list instead of asserting registration.
- PQ-5 — addressed — The ariadne half of the fresh-install criterion moved out with an owner.
- PQ-6 — addressed — M2 carries strategy lines for both resolve_keys and spell.attach.

### Raised

- **PQ-7** [Important] `fix-the-class-not-the-site` M3 specifies the chat behaviour of <M-S-CR> and leaves the markdown half of the same chord undefined
  This is the 2nd finding in family `fix-the-class-not-the-site`; PQ-3 was
  the same rule on M1. Do not patch M3's table alone. The governing rule
  already exists in this issue's `## Revisions` section 3 — "parley commits a
  reference only in a file it owns" — and the plan must state it as the
  column that every row of the M3 table is keyed on, so the next branch-chord
  row cannot omit it either. Measured prevalence: 2 rounds, both on this
  chord, both omitting the markdown twin.
  Failure scenario, verified against the tree: `branch_ref` is
  `scope = "parley_buffer"` (keybinding_registry.lua:484) and init.lua:2702
  builds `md_branch = branch_inserters(buf, true, false)`, wired at :2720 in
  n/i/v; `chat_drill_in` is registered on the same buffers at :2728. So a user
  presses `<M-q>` then `<M-S-CR>` in an ordinary markdown document: contexts 2a
  and 2b apply, but there is no exchange model, no `append_pos`, and no
  colon-summary to land the ref after, and M3's governing sentence resolves to
  `review_next` (keybinding_registry.lua:756, modes n/i only) rather than a
  submission. An implementer following the table literally either crashes on
  the exchange model or silently reintroduces the orphan-child defect M1's
  BR-28 closed.
- **PQ-8** [Important] `branch-ref-creation-ordering` M3's STRIP decision destroys parent content but the plan does not order strip against child creation or say what a failed create leaves behind
  This is the 2nd finding in family `branch-ref-creation-ordering`; PQ-2 was
  the same rule on M1's no-selection path. Do not answer for this row alone —
  state the rule the family needs: any M3 row that mutates the parent before
  the child is durable must name the order of strip / create / commit and the
  state the buffer is left in when a later step fails. Measured prevalence: 2
  rounds, both on the create-child sequence.
  Failure scenario: `insert_inline` (init.lua:2308-2333) mutates the buffer,
  then calls `create_child_if_owned`, which calls `M.create_child_chat`
  unguarded (init.lua:2229-2233), then `commit_reference`, whose failure only
  warns. Under M3 the pre-mutation is the user's `<M-q>` markers removed from
  the parent. If `create_child_chat` raises (chat_dir unwritable, disk full)
  after the strip, the quotes are gone from the parent and were never written
  to a child — unrecoverable, because the markers were the only record of the
  selection. ARCH-ORDER at-plan: name which of cancel / rollback governs, and
  whether the strip is deferred until the child exists on disk.
- **PQ-9** [Important] `test-strategy-per-risky-function` M3 names no functions to unit-test and carries no strategy line, for the milestone the plan itself calls the Critical-producing class
  This is the 2nd finding in family `test-strategy-per-risky-function`; PQ-6
  was the same rule on M2. Do not add one line for one row — state the rule:
  every unchecked Plan row that changes behaviour names the functions it
  changes and carries one adversarial-input line per risky function, the same
  shape M1's "Test: resolve_keys returns all three" and M2's `spell.attach`
  line already use. Measured prevalence: 2 rounds, M2 then M3.
  As written M3 names `gather_and_strip` (drill_in.lua:505) as reused and
  `add_block` / `append_pos` as the placement API, but never says which new
  function is pure, which is the IO seam, or what is under test — so the
  milestone is un-startable without the implementer inventing the split
  (ARCH-PURE at-plan). The adversarial classes are already visible from the
  table: an exchange whose answer has no summary block, markers spread across
  two exchanges, an empty or whitespace-only selection, and a cursor position
  matching none of the five rows.
- **PQ-10** [Minor] `done-when-overstates-plan` Done-when has no acceptance criterion for M3, and M3 row 1 silently changes the child seed M1 shipped
  All six Done-when clauses are keybinding-curation clauses; none of them is
  satisfied or falsified by M3's behaviour, so the M3 boundary has nothing to
  certify against. Separately, row 1 states the child is seeded
  `tell me more about "<sel>"` where the shipped path seeds `topic .. "?"`
  (init.lua:2325) — a change to closed-milestone behaviour presented in the
  column that otherwise describes what exists.

## Open findings

- **PQ-7** [Important] `fix-the-class-not-the-site` M3 specifies the chat behaviour of <M-S-CR> and leaves the markdown half of the same chord undefined
- **PQ-8** [Important] `branch-ref-creation-ordering` M3's STRIP decision destroys parent content but the plan does not order strip against child creation or say what a failed create leaves behind
- **PQ-9** [Important] `test-strategy-per-risky-function` M3 names no functions to unit-test and carries no strategy line, for the milestone the plan itself calls the Critical-producing class
- **PQ-10** [Minor] `done-when-overstates-plan` Done-when has no acceptance criterion for M3, and M3 row 1 silently changes the child seed M1 shipped
