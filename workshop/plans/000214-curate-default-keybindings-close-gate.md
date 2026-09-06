---
gate: boundary-review
issue: 214
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-06T08:43:15-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Critical
          title: Branched child ships an empty topic, so it is never auto-titled and never slugged
          detail: "init.lua:2096 passes \"\" to create_child_chat, whose gsub consumes the\n`topic: ?` sentinel and writes `topic: ` (verified by running it). Auto-topic\ngeneration fires only on `headers.topic == \"?\"` (chat_respond.lua:1934) and\n_slug_rename_chat bails on \"\" (init.lua:2652), so every <M-i> branch is a\npermanently untitled <timestamp>.md and the parent's ref line stays\n`\U0001F33F: ...md: ` forever. Contradicts the docstring at init.lua:2073-2078, the\natlas, and PQ-2's disposition. Pass \"?\" and pin it with a test on the\ncreated header."
          family: created-artifact-skips-lifecycle-trigger
          round: 1
        - id: BR-2
          severity: Important
          title: New pure module lua/parley/branch_ref.lua has zero tests and is absent from traceability.yaml
          detail: |-
            The module docstring justifies its existence as "testable without a
            filesystem (ARCH-PURE)"; no test references it. splice_inline_link
            (start_col > end_col, multibyte prefix, a selection containing "]("),
            format_ref_line with nil topic, and topic_for_selection are all uncovered.
            atlas/traceability.yaml:141-150 still lists only the four old files, so
            make test-changed routes changes to this module nowhere.
          family: pure-extraction-without-tests
          round: 1
        - id: BR-3
          severity: Important
          title: The four M1 chord tests stay green if config.lua's chat_shortcut_branch_ref is deleted
          detail: |-
            keybinding_registry.lua:478 now carries the same key list as config.lua:362.
            Measured resolve_keys with the config key absent, a table without shortcut,
            a bare string, and shortcut = "" — all four return the full default list. So
            the assertion cannot tell which artifact carries the list, which was PQ-1's
            whole point. It also breaks the convention keybindings_spec.lua:270 asserts
            (config-resolved entries carry no default_key, as chat_prune and
            super_repo_toggle do).
          family: test-does-not-pin-the-fix
          round: 1
        - id: BR-4
          severity: Important
          title: branch_inserters(...).i is dead at zero call sites and the chat visual path double-Escs
          detail: |-
            init.lua:2132-2136 returns a complete {n,i,v} table, but both call sites
            rebuild their own wrappers (:2295-2298, :2497-2500 re-implement stopinsert +
            .n(); :2299-2302 wraps .v in an Esc that insert_inline already does at
            :2110). The unified helper advertises three modes and delivers one. Pass
            chat_branch / md_branch directly and delete the wrappers.
          family: duplicate-helper-not-retired
          round: 1
        - id: BR-5
          severity: Important
          title: Three copies of the branch-line formatter survive the consolidation
          detail: |-
            branch_ref.format_ref_line has one caller (:2092); format_branch_ref at
            init.lua:2056 is byte-identical logic 20 lines above it with two callers
            (:3231, :3859); create_child_chat inlines a third at :4535. PQ-3 asked for
            one shared helper both families collapse into. Point the other two at
            br.format_ref_line and add a row to tests/arch/single_source_sweeps_spec.lua,
            whose own preamble says a sweep without a guard is a snapshot.
          family: duplicate-helper-not-retired
          round: 1
        - id: BR-6
          severity: Important
          title: README still documents the superseded primary keys and the old normal-mode behavior
          detail: |-
            README.md:156 documents <C-g>b for branch/prune and :168 documents <C-g>i for
            branch; both are now legacy aliases and the help float advertises <M-p> /
            <M-i> (confirmed against the live help output). README:168 also still says
            "insert a fork in the chat tree" — the normal-mode path now creates the child
            file and switches the window to it.
          family: readme-missing-for-changed-surface
          round: 1
        - id: BR-7
          severity: Important
          title: New atlas Resolution section misdescribes resolve_keys, and the registry comment repeats it
          detail: |-
            atlas/ui/keybindings.md says resolution "does not merge or fall back" and
            that adding a config_key "silently discards whatever default_key held",
            quoting the `if not entry.config_key` early return — the wrong branch.
            Measured: absent config key, table without shortcut, bare string, and
            shortcut = "" all return default_key in full; only a table with a non-empty
            shortcut replaces. keybinding_registry.lua:474-477 states the same
            overstatement. M2's guard shape depends on which is true.
          family: docs-assert-unverified-behavior
          round: 1
        - id: BR-8
          severity: Important
          title: Atlas states the M2 superset guard in the present tense, but it does not exist
          detail: |-
            atlas/ui/keybindings.md: "An arch guard asserts the shipped config resolves
            to a superset of default_key." grep -rn superset lua/ tests/ returns nothing —
            that is an unchecked M2 plan row. Atlas is current state, not planned state.
          family: docs-assert-unverified-behavior
          round: 1
        - id: BR-9
          severity: Important
          title: branch_ref gained a config_key but still cannot be disabled
          detail: |-
            Done-when requires every registered binding to be "rebindable and
            disableable through config". Measured: chat_shortcut_branch_ref =
            { shortcut = "" } resolves to the default three keys, because the empty
            string falls through to default_key. chat_toggle_tool_folds only disables
            because its default_key is nil. M2's resolve_keys row owns the fix; raising
            it so the M2 guard covers the disable direction, not only the shrink one.
          family: config-shadows-default-key
          round: 1
        - id: BR-10
          severity: Important
          title: A child branched from a markdown buffer gets an unresolvable parent back-link
          detail: |-
            create_child_chat:4534 writes the parent's basename, and get_chat_topic
            returns nil at init.lua:2402 for any basename not matching ^%d%d%d%d-%d%d-%d%d.
            From the child in chat_dir, resolve_chat_path tries chat_dir/<md basename>
            and every chat root, then the fuzzy path, which needs a parseable timestamp.
            Pre-existing for the markdown visual path; this diff makes the markdown
            normal/insert path create children too, so it is now reachable from the key
            the atlas documents as the primary branch action.
          family: reference-written-in-unresolvable-form
          round: 1
        - id: BR-11
          severity: Minor
          title: config_tools_spec.lua:434 asserts is_function, not the identity its title claims
          detail: |-
            Reverting chat_toggle_tool_folds = M.cmd.ToggleToolFolds to an inline
            closure leaves the test green. Assert identity against the registry callback.
          family: test-does-not-pin-the-fix
          round: 1
        - id: BR-12
          severity: Minor
          title: keybindings_spec.lua:335 asserts only the absence of <M-S-CR>, so <C-g>i first would pass
          family: test-does-not-pin-the-fix
          round: 1
        - id: BR-13
          severity: Minor
          title: init.lua:1072 web_search comment now sits above ToggleToolFolds; ToggleWebSearch has none
          family: stale-comment-after-move
          round: 1
        - id: BR-14
          severity: Minor
          title: 'init.lua:2474 still reads "markdown-specific: uses format_branch_ref and absolute paths"'
          family: stale-comment-after-move
          round: 1
        - id: BR-15
          severity: Minor
          title: 'Atlas line citations already drift: init.lua:2812-2816 is now :2822, registry:965 is now :971'
          family: volatile-line-citations-in-docs
          round: 1
        - id: BR-16
          severity: Minor
          title: insert_plain returns an unused `link` and ignores abs_link, contradicting its own docstring
          detail: |-
            init.lua:2089,2106 compute and return `link` that no caller reads, and the
            plain path always writes the basename — so the helper's "a markdown file
            elsewhere needs the full path" contract holds only on the inline path.
            Behavior matches the old code, so this is a contract/docstring mismatch.
          family: dead-value-in-new-code
          round: 1
        - id: BR-17
          severity: Minor
          title: :ParleyToggleToolFolds toggles vim.wo.foldenable in any window, including non-chat buffers
          family: command-not-scoped-to-context
          round: 1
        - id: BR-18
          severity: Minor
          title: insert_plain's stopinsert then schedule(edit + startinsert!) has no seam to inject or observe
          detail: |-
            ARCH-ORDER: the i-mode path issues stopinsert (effective at the next
            main-loop pass) and then schedules startinsert!. No test exercises any
            interleaving of that sequence, and there is no way to reproduce a reported
            ordering failure.
          family: no-seam-for-ordering
          round: 1
      boundary: M1
      blocked: true
---

# Gate ledger — parley.nvim#214 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-06T08:43:15-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `created-artifact-skips-lifecycle-trigger` Branched child ships an empty topic, so it is never auto-titled and never slugged
  init.lua:2096 passes "" to create_child_chat, whose gsub consumes the
  `topic: ?` sentinel and writes `topic: ` (verified by running it). Auto-topic
  generation fires only on `headers.topic == "?"` (chat_respond.lua:1934) and
  _slug_rename_chat bails on "" (init.lua:2652), so every <M-i> branch is a
  permanently untitled <timestamp>.md and the parent's ref line stays
  `🌿: ...md: ` forever. Contradicts the docstring at init.lua:2073-2078, the
  atlas, and PQ-2's disposition. Pass "?" and pin it with a test on the
  created header.
- **BR-2** [Important] `pure-extraction-without-tests` New pure module lua/parley/branch_ref.lua has zero tests and is absent from traceability.yaml
  The module docstring justifies its existence as "testable without a
  filesystem (ARCH-PURE)"; no test references it. splice_inline_link
  (start_col > end_col, multibyte prefix, a selection containing "]("),
  format_ref_line with nil topic, and topic_for_selection are all uncovered.
  atlas/traceability.yaml:141-150 still lists only the four old files, so
  make test-changed routes changes to this module nowhere.
- **BR-3** [Important] `test-does-not-pin-the-fix` The four M1 chord tests stay green if config.lua's chat_shortcut_branch_ref is deleted
  keybinding_registry.lua:478 now carries the same key list as config.lua:362.
  Measured resolve_keys with the config key absent, a table without shortcut,
  a bare string, and shortcut = "" — all four return the full default list. So
  the assertion cannot tell which artifact carries the list, which was PQ-1's
  whole point. It also breaks the convention keybindings_spec.lua:270 asserts
  (config-resolved entries carry no default_key, as chat_prune and
  super_repo_toggle do).
- **BR-4** [Important] `duplicate-helper-not-retired` branch_inserters(...).i is dead at zero call sites and the chat visual path double-Escs
  init.lua:2132-2136 returns a complete {n,i,v} table, but both call sites
  rebuild their own wrappers (:2295-2298, :2497-2500 re-implement stopinsert +
  .n(); :2299-2302 wraps .v in an Esc that insert_inline already does at
  :2110). The unified helper advertises three modes and delivers one. Pass
  chat_branch / md_branch directly and delete the wrappers.
- **BR-5** [Important] `duplicate-helper-not-retired` Three copies of the branch-line formatter survive the consolidation
  branch_ref.format_ref_line has one caller (:2092); format_branch_ref at
  init.lua:2056 is byte-identical logic 20 lines above it with two callers
  (:3231, :3859); create_child_chat inlines a third at :4535. PQ-3 asked for
  one shared helper both families collapse into. Point the other two at
  br.format_ref_line and add a row to tests/arch/single_source_sweeps_spec.lua,
  whose own preamble says a sweep without a guard is a snapshot.
- **BR-6** [Important] `readme-missing-for-changed-surface` README still documents the superseded primary keys and the old normal-mode behavior
  README.md:156 documents <C-g>b for branch/prune and :168 documents <C-g>i for
  branch; both are now legacy aliases and the help float advertises <M-p> /
  <M-i> (confirmed against the live help output). README:168 also still says
  "insert a fork in the chat tree" — the normal-mode path now creates the child
  file and switches the window to it.
- **BR-7** [Important] `docs-assert-unverified-behavior` New atlas Resolution section misdescribes resolve_keys, and the registry comment repeats it
  atlas/ui/keybindings.md says resolution "does not merge or fall back" and
  that adding a config_key "silently discards whatever default_key held",
  quoting the `if not entry.config_key` early return — the wrong branch.
  Measured: absent config key, table without shortcut, bare string, and
  shortcut = "" all return default_key in full; only a table with a non-empty
  shortcut replaces. keybinding_registry.lua:474-477 states the same
  overstatement. M2's guard shape depends on which is true.
- **BR-8** [Important] `docs-assert-unverified-behavior` Atlas states the M2 superset guard in the present tense, but it does not exist
  atlas/ui/keybindings.md: "An arch guard asserts the shipped config resolves
  to a superset of default_key." grep -rn superset lua/ tests/ returns nothing —
  that is an unchecked M2 plan row. Atlas is current state, not planned state.
- **BR-9** [Important] `config-shadows-default-key` branch_ref gained a config_key but still cannot be disabled
  Done-when requires every registered binding to be "rebindable and
  disableable through config". Measured: chat_shortcut_branch_ref =
  { shortcut = "" } resolves to the default three keys, because the empty
  string falls through to default_key. chat_toggle_tool_folds only disables
  because its default_key is nil. M2's resolve_keys row owns the fix; raising
  it so the M2 guard covers the disable direction, not only the shrink one.
- **BR-10** [Important] `reference-written-in-unresolvable-form` A child branched from a markdown buffer gets an unresolvable parent back-link
  create_child_chat:4534 writes the parent's basename, and get_chat_topic
  returns nil at init.lua:2402 for any basename not matching ^%d%d%d%d-%d%d-%d%d.
  From the child in chat_dir, resolve_chat_path tries chat_dir/<md basename>
  and every chat root, then the fuzzy path, which needs a parseable timestamp.
  Pre-existing for the markdown visual path; this diff makes the markdown
  normal/insert path create children too, so it is now reachable from the key
  the atlas documents as the primary branch action.
- **BR-11** [Minor] `test-does-not-pin-the-fix` config_tools_spec.lua:434 asserts is_function, not the identity its title claims
  Reverting chat_toggle_tool_folds = M.cmd.ToggleToolFolds to an inline
  closure leaves the test green. Assert identity against the registry callback.
- **BR-12** [Minor] `test-does-not-pin-the-fix` keybindings_spec.lua:335 asserts only the absence of <M-S-CR>, so <C-g>i first would pass
- **BR-13** [Minor] `stale-comment-after-move` init.lua:1072 web_search comment now sits above ToggleToolFolds; ToggleWebSearch has none
- **BR-14** [Minor] `stale-comment-after-move` init.lua:2474 still reads "markdown-specific: uses format_branch_ref and absolute paths"
- **BR-15** [Minor] `volatile-line-citations-in-docs` Atlas line citations already drift: init.lua:2812-2816 is now :2822, registry:965 is now :971
- **BR-16** [Minor] `dead-value-in-new-code` insert_plain returns an unused `link` and ignores abs_link, contradicting its own docstring
  init.lua:2089,2106 compute and return `link` that no caller reads, and the
  plain path always writes the basename — so the helper's "a markdown file
  elsewhere needs the full path" contract holds only on the inline path.
  Behavior matches the old code, so this is a contract/docstring mismatch.
- **BR-17** [Minor] `command-not-scoped-to-context` :ParleyToggleToolFolds toggles vim.wo.foldenable in any window, including non-chat buffers
- **BR-18** [Minor] `no-seam-for-ordering` insert_plain's stopinsert then schedule(edit + startinsert!) has no seam to inject or observe
  ARCH-ORDER: the i-mode path issues stopinsert (effective at the next
  main-loop pass) and then schedules startinsert!. No test exercises any
  interleaving of that sequence, and there is no way to reproduce a reported
  ordering failure.

## Open findings

- **BR-1** [Critical] `created-artifact-skips-lifecycle-trigger` Branched child ships an empty topic, so it is never auto-titled and never slugged
- **BR-2** [Important] `pure-extraction-without-tests` New pure module lua/parley/branch_ref.lua has zero tests and is absent from traceability.yaml
- **BR-3** [Important] `test-does-not-pin-the-fix` The four M1 chord tests stay green if config.lua's chat_shortcut_branch_ref is deleted
- **BR-4** [Important] `duplicate-helper-not-retired` branch_inserters(...).i is dead at zero call sites and the chat visual path double-Escs
- **BR-5** [Important] `duplicate-helper-not-retired` Three copies of the branch-line formatter survive the consolidation
- **BR-6** [Important] `readme-missing-for-changed-surface` README still documents the superseded primary keys and the old normal-mode behavior
- **BR-7** [Important] `docs-assert-unverified-behavior` New atlas Resolution section misdescribes resolve_keys, and the registry comment repeats it
- **BR-8** [Important] `docs-assert-unverified-behavior` Atlas states the M2 superset guard in the present tense, but it does not exist
- **BR-9** [Important] `config-shadows-default-key` branch_ref gained a config_key but still cannot be disabled
- **BR-10** [Important] `reference-written-in-unresolvable-form` A child branched from a markdown buffer gets an unresolvable parent back-link
- **BR-11** [Minor] `test-does-not-pin-the-fix` config_tools_spec.lua:434 asserts is_function, not the identity its title claims
- **BR-12** [Minor] `test-does-not-pin-the-fix` keybindings_spec.lua:335 asserts only the absence of <M-S-CR>, so <C-g>i first would pass
- **BR-13** [Minor] `stale-comment-after-move` init.lua:1072 web_search comment now sits above ToggleToolFolds; ToggleWebSearch has none
- **BR-14** [Minor] `stale-comment-after-move` init.lua:2474 still reads "markdown-specific: uses format_branch_ref and absolute paths"
- **BR-15** [Minor] `volatile-line-citations-in-docs` Atlas line citations already drift: init.lua:2812-2816 is now :2822, registry:965 is now :971
- **BR-16** [Minor] `dead-value-in-new-code` insert_plain returns an unused `link` and ignores abs_link, contradicting its own docstring
- **BR-17** [Minor] `command-not-scoped-to-context` :ParleyToggleToolFolds toggles vim.wo.foldenable in any window, including non-chat buffers
- **BR-18** [Minor] `no-seam-for-ordering` insert_plain's stopinsert then schedule(edit + startinsert!) has no seam to inject or observe
