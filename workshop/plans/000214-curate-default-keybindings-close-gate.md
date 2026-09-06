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
    - "n": 2
      timestamp: "2026-09-06T09:15:13-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'Verified by revert: "?" -> "" turns branch_child_spec:78 red while the three create_child_chat tests stay green.'
          round: 2
        - id: BR-2
          disposition: not-addressed
          note: Tests added, but atlas/traceability.yaml:141-150 is untouched; list-tests chat/inline_branch_links returns neither new spec and omits branch_ref.lua.
          round: 2
        - id: BR-3
          disposition: addressed
          note: 'Verified by revert: deleting chat_shortcut_branch_ref from config.lua turns "config.lua itself ships both chord lists" red.'
          round: 2
        - id: BR-4
          disposition: not-addressed
          note: Chat site fixed; init.lua:2513-2519 still re-implements .i verbatim as stopinsert + md_branch.n().
          round: 2
        - id: BR-5
          disposition: not-addressed
          note: format_branch_ref delegates, but 5 inline restatements remain (init.lua:3066,3600,3613,3671,4564 - the last edited by this commit) and no arch sweep row was added.
          round: 2
        - id: BR-6
          disposition: addressed
          note: README:156,168 now lead with <M-p>/<M-i> and describe the create-and-open behavior.
          round: 2
        - id: BR-7
          disposition: addressed
          note: Re-measured all six config shapes against resolve_keys; the atlas table and the registry comment both match.
          round: 2
        - id: BR-8
          disposition: addressed
          note: grep -rn superset atlas/ lua/ tests/ returns nothing.
          round: 2
        - id: BR-9
          disposition: addressed
          note: 'Plan changed: the M2 resolve_keys row now names BR-9 and owns both shrink and disable directions.'
          round: 2
        - id: BR-10
          disposition: not-addressed
          note: Code present but unreachable in every fixture - reverting to plain basename leaves the suite green; heuristic is filename-shape, so a timestamp-named md outside a chat root still gets an unresolvable ref.
          round: 2
        - id: BR-11
          disposition: not-addressed
          note: 'Verified by revert: restoring the inline closure leaves config_tools_spec 26/26 and keybindings_spec 30/30 green. The added assertion checks the registry entry exists, not the identity the title claims.'
          round: 2
        - id: BR-12
          disposition: addressed
          note: 'Verified by revert: reordering the shipped list to <C-g>i-first turns three tests red.'
          round: 2
        - id: BR-13
          disposition: addressed
          round: 2
        - id: BR-14
          disposition: addressed
          round: 2
        - id: BR-15
          disposition: not-addressed
          note: Atlas citations removed, but the same commit added two new wrong ones - init.lua:2087 cites 2812-2816 for the glob fallback (that is _resolve_chat_path_candidates; the fallback is 2840-2856) and :2112 cites 2652 for the slug topic guard (that is the file_path=="" guard; the topic guard is 2670).
          round: 2
        - id: BR-16
          disposition: addressed
          round: 2
        - id: BR-17
          disposition: not-addressed
          note: 'Guard works live (confirmed: foldenable untouched in a scratch buffer, warning emitted) but no test enters it; reverting it leaves the suite green.'
          round: 2
        - id: BR-18
          disposition: not-addressed
          note: M._branch_inserters lets a test CALL the inserter, not observe ordering. No test invokes .i(), nothing drains the scheduled edit+startinsert!, and the seam's own comment attributes it to BR-1.
          round: 2
      findings:
        - id: BR-19
          severity: Critical
          title: Branch writes the child to disk, leaves the parent's link unsaved, then navigates away - and throws a raw E37 traceback under 'nohidden'
          detail: |-
            Measured in a real chat buffer: after _branch_inserters(buf,false).n() the child
            exists on disk with a back-link while the parent is modified=true and its on-disk
            copy has no line, then focus moves to the child - so a :q! or crash
            orphans the child, which is discoverable only through that link. With set nohidden
            the scheduled vim.cmd("edit") at init.lua:2122 raises "Error executing vim.schedule
            lua callback: Vim(edit):E37: No write since last change" and the window does not
            switch, on the key README and the help float now advertise as primary. The prune
            path already solves this: M.cmd.ChatPrune writes the parent (init.lua:3616) before
            opening the child. ARCH-ORDER: three effects, no rollback, no durable commit of the
            middle one.
          family: partial-effect-not-committed
          round: 2
        - id: BR-20
          severity: Important
          title: Three of this round's fixes survive their own revert with the full suite green
          detail: |-
            This is the 4th finding in family test-does-not-pin-the-fix. Earlier rounds fixed
            instances. Do not fix these instances - fix the rule. Measured prevalence this
            round: BR-10 (parent_ref fallback, no fixture enters the branch), BR-11 (tool-fold
            identity, inline closure restores green), BR-17 (buffer-scope guard, no test enters
            it) all revert clean; BR-18 shipped a seam no test uses. Rule: a milestone-review
            fix lands with its revert demonstrated, and the closing commit's Log names, per
            finding id, the test that goes red without it. A finding for which that line cannot
            be written is disposed deferred, not addressed.
          family: test-does-not-pin-the-fix
          round: 2
        - id: BR-21
          severity: Important
          title: Selection text reaches a gsub replacement unescaped, so branching on a selection containing % throws
          detail: |-
            init.lua:4545 does template:gsub("topic: %?", "topic: " .. topic). Confirmed in Lua:
            topic = 'what is "50% off"' raises "invalid use of '%' in replacement string", and a
            topic containing %1 silently substitutes the capture. Pre-existing on the visual
            path, but M1 promoted <M-i> to the advertised primary key and added
            branch_ref.topic_for_selection as a PURE helper whose spec has no such case. Use a
            function replacement, or escape % -> %%. ARCH-SECURE.
          family: user-text-unescaped-in-lua-pattern
          round: 2
        - id: BR-22
          severity: Important
          title: 8ade807 committed nvim runtime state (state.json, two logs, shada) and .local/ is still not gitignored
          detail: |-
            The commit added .local/share/nvim/parley/persisted/state.json, .local/state/nvim/log,
            .local/state/nvim/parley.nvim.log (203 lines including a full provider-config dump
            with secret = "parley-local" and absolute user paths) and
            .local/state/nvim/shada/main.shada. Library/ and nvim.xianxu/ from the same 08:34
            manual run survive untracked only because they are empty. API keys are redacted, so
            no live credential leaked. .gitignore has no .local/ entry, so the next manual nvim
            run in the repo root reproduces it - and the file's own trailing comment records
            that #205 already hit this class. ARCH-SECURE.
          family: scratch-artifact-swept-into-commit
          round: 2
        - id: BR-23
          severity: Important
          title: The changed-key doc sweep stopped at README; two atlas files still name the superseded primaries
          detail: |-
            This is the 2nd finding in family readme-missing-for-changed-surface. Earlier rounds
            fixed instances. Do not fix this instance - fix the rule. Surviving instances:
            atlas/chat/lifecycle.md:12 "Branching / Pruning (<C-g>b)" and atlas/chat/format.md:16
            "<C-g>i inserts link", in a commit that edited three other atlas files. Rule: when a
            shipped key changes, the deliverable is the enumeration
            grep -rn '<old-key>' README.md ARCH.md atlas/ docs/ lua/ swept in the same commit,
            plus a guard row in tests/arch/single_source_sweeps_spec.lua asserting no doc names a
            key that is not resolve_keys(entry, config)[1]. That file already has the precedent
            row "picker keys come from the keybinding registry, not literals".
          family: readme-missing-for-changed-surface
          round: 2
        - id: BR-24
          severity: Minor
          title: keybinding_registry.lua:478 duplicates config.lua:362's chord list with nothing asserting they agree
          detail: |-
            Dormant today (resolve_keys prefers config), but it is the artifact M2's superset
            guard will compare against, so the two must be reconciled before that guard is
            written or it certifies the duplication rather than the contract.
          family: duplicate-helper-not-retired
          round: 2
        - id: BR-25
          severity: Minor
          title: keybindings_spec.lua:331 dofile("lua/parley/config.lua") is CWD-relative
          detail: |-
            Works only because every runner cd's to the repo root. Resolve against a path
            derived from the spec's own location.
          family: test-harness-assumption
          round: 2
        - id: BR-26
          severity: Minor
          title: branch_ref_spec has no case for a selection containing "](", which breaks the emitted markdown link
          family: pure-extraction-without-tests
          round: 2
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

## Round 2 — 2026-09-06T09:15:13-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — Verified by revert: "?" -> "" turns branch_child_spec:78 red while the three create_child_chat tests stay green.
- BR-2 — not-addressed — Tests added, but atlas/traceability.yaml:141-150 is untouched; list-tests chat/inline_branch_links returns neither new spec and omits branch_ref.lua.
- BR-3 — addressed — Verified by revert: deleting chat_shortcut_branch_ref from config.lua turns "config.lua itself ships both chord lists" red.
- BR-4 — not-addressed — Chat site fixed; init.lua:2513-2519 still re-implements .i verbatim as stopinsert + md_branch.n().
- BR-5 — not-addressed — format_branch_ref delegates, but 5 inline restatements remain (init.lua:3066,3600,3613,3671,4564 - the last edited by this commit) and no arch sweep row was added.
- BR-6 — addressed — README:156,168 now lead with <M-p>/<M-i> and describe the create-and-open behavior.
- BR-7 — addressed — Re-measured all six config shapes against resolve_keys; the atlas table and the registry comment both match.
- BR-8 — addressed — grep -rn superset atlas/ lua/ tests/ returns nothing.
- BR-9 — addressed — Plan changed: the M2 resolve_keys row now names BR-9 and owns both shrink and disable directions.
- BR-10 — not-addressed — Code present but unreachable in every fixture - reverting to plain basename leaves the suite green; heuristic is filename-shape, so a timestamp-named md outside a chat root still gets an unresolvable ref.
- BR-11 — not-addressed — Verified by revert: restoring the inline closure leaves config_tools_spec 26/26 and keybindings_spec 30/30 green. The added assertion checks the registry entry exists, not the identity the title claims.
- BR-12 — addressed — Verified by revert: reordering the shipped list to <C-g>i-first turns three tests red.
- BR-13 — addressed
- BR-14 — addressed
- BR-15 — not-addressed — Atlas citations removed, but the same commit added two new wrong ones - init.lua:2087 cites 2812-2816 for the glob fallback (that is _resolve_chat_path_candidates; the fallback is 2840-2856) and :2112 cites 2652 for the slug topic guard (that is the file_path=="" guard; the topic guard is 2670).
- BR-16 — addressed
- BR-17 — not-addressed — Guard works live (confirmed: foldenable untouched in a scratch buffer, warning emitted) but no test enters it; reverting it leaves the suite green.
- BR-18 — not-addressed — M._branch_inserters lets a test CALL the inserter, not observe ordering. No test invokes .i(), nothing drains the scheduled edit+startinsert!, and the seam's own comment attributes it to BR-1.

### Raised

- **BR-19** [Critical] `partial-effect-not-committed` Branch writes the child to disk, leaves the parent's link unsaved, then navigates away - and throws a raw E37 traceback under 'nohidden'
  Measured in a real chat buffer: after _branch_inserters(buf,false).n() the child
  exists on disk with a back-link while the parent is modified=true and its on-disk
  copy has no line, then focus moves to the child - so a :q! or crash
  orphans the child, which is discoverable only through that link. With set nohidden
  the scheduled vim.cmd("edit") at init.lua:2122 raises "Error executing vim.schedule
  lua callback: Vim(edit):E37: No write since last change" and the window does not
  switch, on the key README and the help float now advertise as primary. The prune
  path already solves this: M.cmd.ChatPrune writes the parent (init.lua:3616) before
  opening the child. ARCH-ORDER: three effects, no rollback, no durable commit of the
  middle one.
- **BR-20** [Important] `test-does-not-pin-the-fix` Three of this round's fixes survive their own revert with the full suite green
  This is the 4th finding in family test-does-not-pin-the-fix. Earlier rounds fixed
  instances. Do not fix these instances - fix the rule. Measured prevalence this
  round: BR-10 (parent_ref fallback, no fixture enters the branch), BR-11 (tool-fold
  identity, inline closure restores green), BR-17 (buffer-scope guard, no test enters
  it) all revert clean; BR-18 shipped a seam no test uses. Rule: a milestone-review
  fix lands with its revert demonstrated, and the closing commit's Log names, per
  finding id, the test that goes red without it. A finding for which that line cannot
  be written is disposed deferred, not addressed.
- **BR-21** [Important] `user-text-unescaped-in-lua-pattern` Selection text reaches a gsub replacement unescaped, so branching on a selection containing % throws
  init.lua:4545 does template:gsub("topic: %?", "topic: " .. topic). Confirmed in Lua:
  topic = 'what is "50% off"' raises "invalid use of '%' in replacement string", and a
  topic containing %1 silently substitutes the capture. Pre-existing on the visual
  path, but M1 promoted <M-i> to the advertised primary key and added
  branch_ref.topic_for_selection as a PURE helper whose spec has no such case. Use a
  function replacement, or escape % -> %%. ARCH-SECURE.
- **BR-22** [Important] `scratch-artifact-swept-into-commit` 8ade807 committed nvim runtime state (state.json, two logs, shada) and .local/ is still not gitignored
  The commit added .local/share/nvim/parley/persisted/state.json, .local/state/nvim/log,
  .local/state/nvim/parley.nvim.log (203 lines including a full provider-config dump
  with secret = "parley-local" and absolute user paths) and
  .local/state/nvim/shada/main.shada. Library/ and nvim.xianxu/ from the same 08:34
  manual run survive untracked only because they are empty. API keys are redacted, so
  no live credential leaked. .gitignore has no .local/ entry, so the next manual nvim
  run in the repo root reproduces it - and the file's own trailing comment records
  that #205 already hit this class. ARCH-SECURE.
- **BR-23** [Important] `readme-missing-for-changed-surface` The changed-key doc sweep stopped at README; two atlas files still name the superseded primaries
  This is the 2nd finding in family readme-missing-for-changed-surface. Earlier rounds
  fixed instances. Do not fix this instance - fix the rule. Surviving instances:
  atlas/chat/lifecycle.md:12 "Branching / Pruning (<C-g>b)" and atlas/chat/format.md:16
  "<C-g>i inserts link", in a commit that edited three other atlas files. Rule: when a
  shipped key changes, the deliverable is the enumeration
  grep -rn '<old-key>' README.md ARCH.md atlas/ docs/ lua/ swept in the same commit,
  plus a guard row in tests/arch/single_source_sweeps_spec.lua asserting no doc names a
  key that is not resolve_keys(entry, config)[1]. That file already has the precedent
  row "picker keys come from the keybinding registry, not literals".
- **BR-24** [Minor] `duplicate-helper-not-retired` keybinding_registry.lua:478 duplicates config.lua:362's chord list with nothing asserting they agree
  Dormant today (resolve_keys prefers config), but it is the artifact M2's superset
  guard will compare against, so the two must be reconciled before that guard is
  written or it certifies the duplication rather than the contract.
- **BR-25** [Minor] `test-harness-assumption` keybindings_spec.lua:331 dofile("lua/parley/config.lua") is CWD-relative
  Works only because every runner cd's to the repo root. Resolve against a path
  derived from the spec's own location.
- **BR-26** [Minor] `pure-extraction-without-tests` branch_ref_spec has no case for a selection containing "](", which breaks the emitted markdown link

## Open findings

- **BR-2** [Important] `pure-extraction-without-tests` New pure module lua/parley/branch_ref.lua has zero tests and is absent from traceability.yaml
- **BR-4** [Important] `duplicate-helper-not-retired` branch_inserters(...).i is dead at zero call sites and the chat visual path double-Escs
- **BR-5** [Important] `duplicate-helper-not-retired` Three copies of the branch-line formatter survive the consolidation
- **BR-10** [Important] `reference-written-in-unresolvable-form` A child branched from a markdown buffer gets an unresolvable parent back-link
- **BR-11** [Minor] `test-does-not-pin-the-fix` config_tools_spec.lua:434 asserts is_function, not the identity its title claims
- **BR-15** [Minor] `volatile-line-citations-in-docs` Atlas line citations already drift: init.lua:2812-2816 is now :2822, registry:965 is now :971
- **BR-17** [Minor] `command-not-scoped-to-context` :ParleyToggleToolFolds toggles vim.wo.foldenable in any window, including non-chat buffers
- **BR-18** [Minor] `no-seam-for-ordering` insert_plain's stopinsert then schedule(edit + startinsert!) has no seam to inject or observe
- **BR-19** [Critical] `partial-effect-not-committed` Branch writes the child to disk, leaves the parent's link unsaved, then navigates away - and throws a raw E37 traceback under 'nohidden'
- **BR-20** [Important] `test-does-not-pin-the-fix` Three of this round's fixes survive their own revert with the full suite green
- **BR-21** [Important] `user-text-unescaped-in-lua-pattern` Selection text reaches a gsub replacement unescaped, so branching on a selection containing % throws
- **BR-22** [Important] `scratch-artifact-swept-into-commit` 8ade807 committed nvim runtime state (state.json, two logs, shada) and .local/ is still not gitignored
- **BR-23** [Important] `readme-missing-for-changed-surface` The changed-key doc sweep stopped at README; two atlas files still name the superseded primaries
- **BR-24** [Minor] `duplicate-helper-not-retired` keybinding_registry.lua:478 duplicates config.lua:362's chord list with nothing asserting they agree
- **BR-25** [Minor] `test-harness-assumption` keybindings_spec.lua:331 dofile("lua/parley/config.lua") is CWD-relative
- **BR-26** [Minor] `pure-extraction-without-tests` branch_ref_spec has no case for a selection containing "](", which breaks the emitted markdown link
