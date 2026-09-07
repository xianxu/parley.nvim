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
    - "n": 3
      timestamp: "2026-09-06T09:31:47-07:00"
      agent: claude
      boundary: M1
      blocked: true
      protocol_error: no valid findings block
    - "n": 4
      timestamp: "2026-09-06T09:55:45-07:00"
      agent: claude
      dispose:
        - id: BR-2
          disposition: not-addressed
          note: Tests now exist (branch_ref_spec, 9 assertions, no IO); atlas/traceability.yaml:141-150 still lists only the four old files, so branch_ref.lua and both new specs route nowhere under make test-changed.
          round: 4
        - id: BR-4
          disposition: not-addressed
          note: Chat site fixed (branch_ref = chat_branch); init.lua:2551-2557 still rebuilds n/i/v wrappers for markdown, so .i remains dead at zero call sites.
          round: 4
        - id: BR-5
          disposition: addressed
          note: All full-line formatter sites route through branch_ref.format_ref_line; the arch guard at single_source_sweeps_spec.lua:378 is real.
          round: 4
        - id: BR-10
          disposition: not-addressed
          note: Code fix is correct and reachable, but reverting parent_ref to the bare basename leaves the FULL suite green — measured in a git clone.
          round: 4
        - id: BR-11
          disposition: not-addressed
          note: config_tools_spec.lua:436-447 still asserts only is_function plus registry-entry existence; reverting the callback to an inline closure leaves the full suite green — measured.
          round: 4
        - id: BR-15
          disposition: addressed
          note: No .lua:NNNN citation from this range survives in atlas/; the one code citation added (chat_respond.lua:1934) is accurate — verified.
          round: 4
        - id: BR-17
          disposition: not-addressed
          note: Guard added but no spec invokes ToggleToolFolds; deleting the guard leaves the full suite green — measured. Warning text says "chat buffers only" while markdown satisfies the guard.
          round: 4
        - id: BR-18
          disposition: not-addressed
          note: M._branch_inserters seam exists and specs now drive it, but nothing observes the stopinsert -> schedule(edit/G/startinsert!) interleaving; branch_child_spec also leaves two unflushed schedules while after_each deletes the tmpdir.
          round: 4
        - id: BR-19
          disposition: addressed
          note: 'Mutation-verified in a clone: removing the plain-path commit, the inline commit, or the scope guard each turns branch_child_spec red. The markdown residue is raised separately, not as BR-19.'
          round: 4
        - id: BR-20
          disposition: not-addressed
          note: 'Measured this round: BR-10, BR-11, BR-17 and BR-21 each revert clean with the full suite green; the issue''s Log names no per-finding test.'
          round: 4
        - id: BR-21
          disposition: not-addressed
          note: init.lua:4586 uses a function replacement correctly, but branch_ref_spec.lua:53-67 re-implements the gsub in the test body; reverting to string concat leaves the full suite green — measured.
          round: 4
        - id: BR-22
          disposition: not-addressed
          note: .gitignore entry landed and HEAD's tree is clean, but 8ade807 still carries the four blobs (14 KB log with secret = "parley-local" and absolute paths); they reach main unless the branch is squashed or rebased.
          round: 4
        - id: BR-23
          disposition: not-addressed
          note: Both atlas instances swept, but the rule half was not delivered — no guard row asserts a doc names resolve_keys(entry, config)[1]; the row that landed guards the branch-ref formatter instead.
          round: 4
        - id: BR-24
          disposition: not-addressed
          note: keybinding_registry.lua:478 still duplicates config.lua's list byte-for-byte with nothing asserting they agree.
          round: 4
        - id: BR-25
          disposition: not-addressed
          note: keybindings_spec.lua:349 is still dofile("lua/parley/config.lua"), CWD-relative.
          round: 4
        - id: BR-26
          disposition: not-addressed
          note: branch_ref_spec has no case for a selection containing "](" nor for one ending mid-codepoint.
          round: 4
      findings:
        - id: BR-27
          severity: Critical
          title: Markdown normal/insert branch lost its cursor move and startinsert — the key now appears to do nothing
          detail: |-
            commit_reference() returns false on any non-chat buffer and insert_plain
            treats that as "do not navigate" and returns, but the pre-#214 markdown
            path did not navigate either — it moved the cursor onto the new ref line
            and scheduled startinsert! so the user could type the topic. Measured
            through the real keymap: base 54a5c7a2 leaves cursor {3,34} with
            startinsert! queued and chat_dir empty; HEAD leaves cursor {2,0} in normal
            mode with a child file created. The code comment claims it "keeps the
            pre-#214 behaviour"; it does not. No test observes the markdown path.
          family: merged-path-loses-original-effect
          round: 4
        - id: BR-28
          severity: Important
          title: On a markdown buffer the branch key creates a child on disk whose only reference is never committed
          detail: |-
            This is the 2nd finding in this family. Do not fix the instance. Round 3's
            rule enumerated the dispatch table's MODES; the component's state space is
            modes x buffer types, and the markdown cell creates the durable artifact
            while committing nothing and navigating nowhere — the exact BR-19 shape,
            relocated. Restate the rule as: every cell of modes x buffer types either
            commits the reference or does not create the artifact. For markdown the
            cheap resolution is the second half.
          family: partial-effect-not-committed
          round: 4
        - id: BR-29
          severity: Important
          title: atlas/chat/inline_branch_links.md says markdown opens the child and that the two buffer types differ only in link target
          detail: |-
            This is the 3rd finding in this family. Do not fix the instance. Both
            claims at :6-19 are false at HEAD — markdown never opens the child and the
            types also diverge on parent-commit and navigation — and the atlas never
            records that branching now :writes the parent buffer at all. Round 3 stated
            the rule and broke it in the same commit that applied it to README, which
            is the signal the family needs a mechanism: sweep every effect verb
            ("creates", "opens", "writes", "saves", "renames", "only") added by
            git diff --name-only <base> HEAD -- atlas/ README.md before the closing
            commit, and pin the surviving claims with a spec that exercises them.
            README is correctly scoped to "In Chat Buffer" and is fine.
          family: docs-assert-unverified-behavior
          round: 4
        - id: BR-30
          severity: Important
          title: The issue Plan still states three superseded M1 decisions and has no Revisions section
          detail: |-
            Row 1 names global_shortcut_branch_ref and the order {<M-S-CR>, <M-i>,
            <C-g>i}; the code ships chat_shortcut_branch_ref with <M-i> first. Row 3
            says "create immediately with an empty topic"; BR-1 established "?" and the
            code ships it. Row 2 is checked on "so the pair cannot drift again" while
            the markdown call site still re-implements .i and the two types diverge on
            three effects. AGENTS.md section 1 requires an appended "## Revisions"
            entry; the file has no such section, and this is the artifact the close
            gate's plan-unchecked guard reads.
          family: plan-not-revised-after-decision-change
          round: 4
        - id: BR-31
          severity: Minor
          title: chat_finder.lua:777 still hand-builds the inline branch-link format the new arch guard does not see
          detail: |-
            This is the 4th finding in this family. Do not fix the instance. The guard
            at single_source_sweeps_spec.lua:378 matches one literal concatenation
            idiom (branch_prefix .. " " ..), which is why the sweep keeps missing
            siblings. The rule: key the guard on the emitted SHAPE — "](" adjacent to a
            .md path, and ": " after a prefix variable — not on one spelling of the
            concatenation.
          family: duplicate-helper-not-retired
          round: 4
        - id: BR-32
          severity: Minor
          title: commit_reference discards the write error, and the success log line fires before the committed check
          detail: |-
            init.lua:2114-2119 pcalls the write and drops the error, so a failure
            reports "could not save the parent" with no cause. init.lua:2148 logs
            "Created branch to new chat: <file>" before the committed check, announcing
            success on the path where nothing was committed and nothing opened.
          family: partial-effect-not-committed
          round: 4
      boundary: M1
      blocked: true
    - "n": 5
      timestamp: "2026-09-06T10:18:15-07:00"
      agent: claude
      dispose:
        - id: BR-2
          disposition: not-addressed
          note: Spec landed; atlas/traceability.yaml still has no branch_ref.lua, branch_ref_spec or branch_child_spec, so make test-changed routes the new module nowhere.
          round: 5
        - id: BR-4
          disposition: not-addressed
          note: Chat site now passes the table through; init.lua:2570-2577 still re-implements .i around md_branch.n.
          round: 5
        - id: BR-10
          disposition: not-addressed
          note: 'Measured: reverting parent_ref to the plain basename leaves branch_child_spec 7/0/0; the only path reaching the fallback is the markdown-visual cell BR-28 says must not create a child.'
          round: 5
        - id: BR-11
          disposition: not-addressed
          note: 'Measured: restoring the inline closure leaves config_tools_spec 26/0/0 and keybindings_spec 30/0/0; the added assertion checks the registry entry exists, not the identity.'
          round: 5
        - id: BR-17
          disposition: not-addressed
          note: 'Measured: deleting the _parley_bufs guard from M.cmd.ToggleToolFolds leaves both specs green; no test enters it.'
          round: 5
        - id: BR-18
          disposition: not-addressed
          note: .i() is driven now, but nothing drains or orders the scheduled startinsert!/edit, so no interleaving is observable.
          round: 5
        - id: BR-20
          disposition: not-addressed
          note: Measured prevalence this round is 4/4 - BR-10, BR-11, BR-17 and BR-21 all revert clean with the suite green; no Log line names a red test per finding id.
          round: 5
        - id: BR-21
          disposition: not-addressed
          note: branch_ref_spec.lua:53-66 runs the fixed gsub inside the test body; reverting init.lua's function replacement leaves branch_ref_spec 9/0/0 and branch_child_spec 7/0/0.
          round: 5
        - id: BR-22
          disposition: addressed
          note: Files removed in f617b96 and .gitignore carries .local/ with the cause; git ls-files shows none at HEAD.
          round: 5
        - id: BR-23
          disposition: not-addressed
          note: lifecycle.md and format.md were swept, but the guard row the rule called for was not added to single_source_sweeps_spec.lua.
          round: 5
        - id: BR-24
          disposition: not-addressed
          note: keybinding_registry.lua:478 and config.lua:362 still carry the same list with nothing asserting they agree.
          round: 5
        - id: BR-25
          disposition: not-addressed
          note: keybindings_spec.lua:331 still dofiles a CWD-relative path.
          round: 5
        - id: BR-26
          disposition: not-addressed
          note: No case for a selection containing "](" in branch_ref_spec.
          round: 5
        - id: BR-27
          disposition: addressed
          note: Pinned by branch_child_spec.lua:157-176 (cursor on the new line); the scheduled startinsert! half is still unasserted, which is BR-18.
          round: 5
        - id: BR-28
          disposition: not-addressed
          note: 'Reproduced at HEAD: on a foreign markdown buffer insert_inline (init.lua:2199-2204) creates the child and commit_reference returns false without writing - the rule was applied to n/i only.'
          round: 5
        - id: BR-29
          disposition: not-addressed
          note: 'inline_branch_links.md:18 ("creates the child: no") contradicts :22 ("Visual mode ... creates the child") and the code follows :22; init.lua:2078-2082 still claims abs_link is the only difference and the topic is empty.'
          round: 5
        - id: BR-30
          disposition: not-addressed
          note: Revisions section exists but records one of the three named deltas; Row 1's global_shortcut_branch_ref and Row 3's "empty topic" are still stated as shipped.
          round: 5
        - id: BR-31
          disposition: not-addressed
          note: chat_finder.lua:777 still hand-builds the inline link; the new guard matches only the `branch_prefix .. " " ..` idiom, not the emitted shape.
          round: 5
        - id: BR-32
          disposition: not-addressed
          note: Log ordering fixed; init.lua:2113 still discards the pcall error so a failed write reports no cause.
          round: 5
      findings:
        - id: BR-33
          severity: Important
          title: branch_inserters reads ownership from the global M._parley_bufs at keypress instead of taking it from the call site that already knows
          detail: |-
            init.lua:2110 and :2137 derive owns_file from a map the highlighter maintains
            (highlighter.lua:1063,1078,1138), while abs_link - the lesser fact - is a
            parameter. Both call sites know statically: prep_chat runs only for chat
            buffers, setup_markdown_keymaps only for markdown. Consequences measured in
            this diff: insert_inline omits the check with no signature saying it must
            not (that is BR-28); branch_child_spec.lua:77 must poke private state to
            reach the chat path, so the test fakes the thing under test; and a cleared
            entry (BufUnload, handle reuse) silently degrades a real chat buffer to
            foreign behaviour - no child, no write, no navigation. Pass
            { abs_link = ..., owns_file = ... } from both call sites, then the
            guarantee table is enforced by the signature rather than by a comment.
            ARCH-ORDER, ARCH-MOCK.
          family: state-rederived-instead-of-passed
          round: 5
      boundary: M1
      blocked: false
    - "n": 6
      timestamp: "2026-09-07T13:47:38-07:00"
      agent: claude
      dispose:
        - id: BR-2
          disposition: not-addressed
          note: branch_ref_spec ships and passes 7, but atlas/traceability.yaml:141-150 still lists only the four old code files and three old tests - branch_ref.lua, branch_ref_spec.lua and branch_child_spec.lua are all absent, so make test-changed still routes nothing to them.
          round: 6
        - id: BR-4
          disposition: not-addressed
          note: Chat passes the table through (init.lua:2391); init.lua:2584-2589 still rebuilds .i around md_branch.n, so half the pair hand-wires and the Plan row claiming "the pair cannot drift again" is still not true.
          round: 6
        - id: BR-10
          disposition: addressed
          note: 'Verified by revert: parent_ref -> bare parent_rel leaves branch_child_spec 11/1.'
          round: 6
        - id: BR-11
          disposition: not-addressed
          note: 'Verified by revert for the 4th round: an inline closure at init.lua:2429 leaves config_tools_spec 26/0, keybindings_spec 30/0 and branch_child_spec 12/0. The new test asserts the registry ENTRY exists, not that its callback IS M.cmd.ToggleToolFolds.'
          round: 6
        - id: BR-17
          disposition: addressed
          note: 'Verified by revert: removing the guard leaves branch_child_spec 11/1. Minor residual - the guard is `not M._parley_bufs[buf]`, so it also admits parley markdown buffers while the warning says "chat buffers only".'
          round: 6
        - id: BR-18
          disposition: not-addressed
          note: M._branch_inserters is a call seam, not an ordering seam. Nothing flushes or observes the schedule(edit -> G -> startinsert!), and the run leaks it - E211 "File .../plain-notes.md no longer available" plus three log lines printed after the suite summary.
          round: 6
        - id: BR-20
          disposition: not-addressed
          note: Improved but not in force. Measured this round 4/6 pin (BR-10, BR-17, BR-21, BR-28 all go red on revert); BR-11 and BR-33 revert clean. The issue's Log still names no test per finding id - those statements live only in the commit body.
          round: 6
        - id: BR-21
          disposition: addressed
          note: 'Verified by revert: string concat leaves branch_child_spec 10/2. The site is fixed and pinned; the CLASS is not - see the new finding.'
          round: 6
        - id: BR-23
          disposition: not-addressed
          note: 'Instances swept (verified - only alias mentions remain in README/ARCH/atlas/lua). The rule half was not delivered: no guard row asserts a doc names only keys in resolve_keys(entry, config); the one new arch row is about the branch-ref formatter.'
          round: 6
        - id: BR-24
          disposition: not-addressed
          note: keybinding_registry.lua:478 and config.lua:362 still carry the same three-key list with nothing asserting they agree.
          round: 6
        - id: BR-25
          disposition: not-addressed
          note: keybindings_spec.lua:350 dofile("lua/parley/config.lua") is still CWD-relative.
          round: 6
        - id: BR-26
          disposition: not-addressed
          note: branch_ref_spec has no case for a selection containing "](", nor for one ending in a multibyte character.
          round: 6
        - id: BR-28
          disposition: addressed
          note: 'Verified by revert: restoring the direct create_child_chat in insert_inline leaves branch_child_spec 11/1. The six-cell spec iterates both axes and fires.'
          round: 6
        - id: BR-29
          disposition: not-addressed
          note: The two named claims are gone, but three new unverified ones landed in the same file - :7 states the signature as branch_inserters(buf, abs_link) when it takes three params; :22 says visual mode "creates the child" unconditionally, contradicting the table four lines above for foreign markdown; the table's "after the keypress = opens the child" is false for the chat x visual cell, which stays in the parent; and :36 "Child gets a parent back-link" is false for the markdown full-line path, which routes through init.lua:3939 where the back-link is skipped for a non-chat source. No spec exercises any atlas or README claim, which is the rule half that keeps not shipping.
          round: 6
        - id: BR-30
          disposition: not-addressed
          note: Revisions records the chord order, the tool-fold decision and the buffer-type divergence. Two of BR-30's three named deltas are still missing - Row 1's global_shortcut_branch_ref (code ships chat_shortcut_branch_ref) and Row 3's "empty topic" (code ships "?"). Row 2 is still [x] on "so the pair cannot drift again" while init.lua:2584-2589 re-implements .i.
          round: 6
        - id: BR-31
          disposition: not-addressed
          note: chat_finder.lua:777 is unchanged and the guard at single_source_sweeps_spec.lua:381 still matches the literal `branch_prefix .. " " ..` idiom, so the inline shape splice_inline_link owns has no owner and no guard.
          round: 6
        - id: BR-32
          disposition: not-addressed
          note: The log-ordering half is fixed. init.lua:2126 still writes `local ok = pcall(...)`, dropping the cause. Sibling in the same function - init.lua:2218 logs "Created inline branch to new chat" on the foreign-markdown path where no child was created.
          round: 6
        - id: BR-33
          disposition: addressed
          note: Both call sites now pass ownership (init.lua:2296, :2565) and neither mode reads M._parley_bufs. Residual raised separately as a Minor - two independent booleans do not encode the guarantee table in the signature the way the finding asked. branch_child_spec.lua:77's poke is now vestigial.
          round: 6
      findings:
        - id: BR-34
          severity: Important
          title: BR-21 was fixed at one site; four gsub-replacement siblings survive, one of them the child-creation path M1 routes markdown branches to
          detail: |-
            This is the 2nd finding in family user-text-unescaped-in-lua-pattern. Do NOT fix the
            named instances - state the rule and sweep the enumeration in this round. Rule - a
            runtime string may never be the second argument to gsub/sub; use a function
            replacement or escape %. Enumeration is `grep -n ':gsub(' lua/parley/*.lua` filtered
            to non-literal replacements. Surviving at HEAD - init.lua:3936 and :4079 and :4241
            substitute a user topic into `{{topic}}`, init.lua:3272 substitutes initial_question.
            Measured in this repo's LuaJIT, which does NOT raise - "50% off" becomes "50 off",
            "%1 placeholder" becomes "{{topic}} placeholder", "100%" writes a NUL byte. So the
            failure is silent corruption of the child's topic header. init.lua:3936 is load-
            bearing for M1 - the atlas states that on a foreign markdown buffer "the child is
            created when the link is followed", and that is this call. init.lua:3930-3950 and
            :4060-4085 are two hand-rolled re-implementations of create_child_chat; collapsing
            them onto it fixes the class and the duplication together. ARCH-SECURE, ARCH-PURPOSE.
          family: user-text-unescaped-in-lua-pattern
          round: 6
        - id: BR-35
          severity: Minor
          title: branch_inserters takes two independent booleans that encode one bit, so two of the four representable states are illegal and untested
          detail: |-
            init.lua:2090 - branch_inserters(buf, abs_link, owns_file). The two call sites pass
            exactly mirrored literals, (buf, false, true) at :2296 for chat and (buf, true, false)
            at :2565 for markdown, and branch_child_spec hand-writes the same pairs at five
            places. (true, true) and (false, false) are representable, mean nothing, and no test
            covers them. BR-33's stated purpose was that "the guarantee table is enforced by the
            signature rather than by a comment"; two independent booleans do not do that. Collapse
            to one tagged parameter - kind = "chat" | "foreign" - and derive both facts from it.
            ARCH-ORDER.
          family: illegal-state-representable-in-signature
          round: 6
      boundary: M1
      blocked: false
    - "n": 7
      timestamp: "2026-09-07T14:02:24-07:00"
      agent: claude
      dispose:
        - id: BR-2
          disposition: not-addressed
          note: Tests shipped (branch_ref_spec, 7 cases, green); atlas/traceability.yaml:141-150 is unchanged, so branch_ref.lua and both new specs are still mapped nowhere.
          round: 7
        - id: BR-4
          disposition: not-addressed
          note: Chat site fixed (init.lua:2391 passes chat_branch directly); init.lua:2583-2589 still rebuilds the table and re-implements `stopinsert; .n()`, which is verbatim `.i`.
          round: 7
        - id: BR-11
          disposition: not-addressed
          note: Verified by revert - replacing chat_toggle_tool_folds with an inline closure leaves config_tools_spec at 26/26. The new assertions check is_function and registry membership, never callback identity.
          round: 7
        - id: BR-18
          disposition: not-addressed
          note: M._branch_inserters exists and is used, but no test observes or injects the stopinsert -> schedule(edit + startinsert!) interleaving.
          round: 7
        - id: BR-20
          disposition: not-addressed
          note: Rule not built. Measured this round - BR-11 reverts clean, and the round's own init.lua:3272 gsub fix reverts clean with the arch and integration specs green. No per-finding-id test line in the Log.
          round: 7
        - id: BR-23
          disposition: not-addressed
          note: Both named doc lines swept, but the required guard row (no doc names a key that is not resolve_keys(entry, config)[1]) was not added to single_source_sweeps_spec.lua. The guard was the deliverable.
          round: 7
        - id: BR-24
          disposition: not-addressed
          note: keybinding_registry.lua:478 still duplicates config.lua:362 with nothing asserting agreement.
          round: 7
        - id: BR-25
          disposition: not-addressed
          note: keybindings_spec.lua:350 unchanged. Three pre-existing specs share the idiom, so the fix belongs in a shared repo-root helper.
          round: 7
        - id: BR-26
          disposition: not-addressed
          note: branch_ref_spec still has no case for a selection containing "](".
          round: 7
        - id: BR-29
          disposition: not-addressed
          note: Named claims corrected, rule not built, and two new false claims shipped in the same commit - atlas:7 states a 2-arg signature (3 params at HEAD) and atlas:20 states "opens the child" for the chat column, false for visual mode since create_child_chat only writes the file.
          round: 7
        - id: BR-30
          disposition: not-addressed
          note: Revisions records the chord order, tool-fold decision and buffer-type divergence. Row 1's global_shortcut_branch_ref (no such key exists) and Row 3's "empty topic" (code ships "?") are still stated as shipped.
          round: 7
        - id: BR-31
          disposition: not-addressed
          note: chat_finder.lua fixed; the guard at single_source_sweeps_spec.lua:388 still matches the literal `branch_prefix .. " " ..` idiom rather than the emitted shape.
          round: 7
        - id: BR-32
          disposition: not-addressed
          note: Log ordering IS fixed. init.lua:2126 still drops pcall's error, so "could not save the parent" ships with no cause.
          round: 7
        - id: BR-34
          disposition: not-addressed
          note: Four init.lua sites fixed, but issues.lua:662,663,665 - inside the finding's own `lua/parley/*.lua` enumeration - still pass runtime strings; the guard catches 1 of 5 planted shapes and misses the `or ""` form that is the live violation.
          round: 7
        - id: BR-35
          disposition: not-addressed
          note: Signature is still branch_inserters(buf, abs_link, owns_file); (true,true) and (false,false) remain representable and untested.
          round: 7
      findings:
        - id: BR-36
          severity: Important
          title: On a foreign markdown buffer the debounced refresh appends a warning to the line the user is typing the topic into
          detail: |-
            This is the 2nd finding in family no-seam-for-ordering. Do NOT fix the
            instance - state the rule. insert_plain calls highlight_chat_branch_refs
            before the non-owned early return (init.lua:2170), arming the 500ms
            debounce at highlighter.lua:816. No child is created on that path, so
            render_chat_branch_line sees filereadable == 0 and rewrites the line with
            " warning-emoji" appended after whatever the user has typed, in insert
            mode. Measured - immediately the line is the bare ref, after typing it is
            "topic", after 900ms it is "topic + warning". It does not accumulate
            across five refreshes. The behaviour predates #214, but this milestone
            re-blessed the path as a stated guarantee (atlas table row "cursor on the
            new line, insert mode") and pinned it with branch_child_spec:181-204,
            which asserts only the synchronous state and therefore passes while the
            settled line differs. Rule - a branch path that arms a timer or schedules
            an effect is not pinned by a test asserting the buffer immediately after
            the call; the test must advance past the debounce and assert the settled
            line. That rule is enumerable over every vim.schedule and every
            highlight_chat_branch_refs call in the branch paths.
          family: no-seam-for-ordering
          round: 7
        - id: BR-37
          severity: Minor
          title: 'c8cccd0 swept 462 lines of unrelated workshop/parley transcripts into a commit whose subject is a #220 process-leak filing'
          detail: |-
            This is the 2nd finding in family scratch-artifact-swept-into-commit. Do
            NOT fix the instance - state the rule. BR-22's fix was a .gitignore rule
            for .local/, which cannot generalize to this case - workshop/parley
            transcripts are wanted, tracked artifacts that landed in the wrong commit,
            so no ignore rule reaches them. The rule is staging discipline - stage the
            enumerated paths the commit subject names, never `git add -A`, and if a
            commit carries anything outside its issue's touch set, name it in the body.
          family: scratch-artifact-swept-into-commit
          round: 7
      boundary: M1
      blocked: false
    - "n": 8
      timestamp: "2026-09-07T14:33:09-07:00"
      agent: claude
      boundary: M2
      blocked: false
      protocol_error: no valid findings block
    - "n": 9
      timestamp: "2026-09-07T15:05:18-07:00"
      agent: claude
      findings:
        - id: BR-38
          severity: Important
          title: default_keymaps = false does not revoke global maps installed by an earlier setup()
          detail: |-
            Measured by keymap diff: setup() then setup({default_keymaps=false}) leaves 43
            global parley mappings live (<C-G>c/f/w, all <C-J>*, <C-N>*, <C-Y>*). register_global
            samples the switch once and has no teardown. config.lua:340 and atlas/ui/keybindings.md
            describe the limitation as buffer-local only, so the docs do not cover this.
            3rd in family: round 8 raised the buffer half as a Minor; the fix addressed buffers
            and never revisited the other sample site. Rule: every site that samples
            default_keymaps makes the decision durable, so each needs a stated reversibility rule
            and an assertion. Enumeration: register_global (setup-time, no teardown),
            register_buffer via prep_chat/setup_markdown_keymaps (_prepared_bufs-guarded),
            native_map (init.lua:2341, same guard).
          family: no-seam-for-ordering
          round: 9
        - id: BR-39
          severity: Important
          title: the no-leaks guard detects parley maps by a desc convention nothing enforces
          detail: |-
            keybinding_agreement_spec.lua:71-79 filters on desc containing "parley". 46 of 81
            registry entries have descs that do not ("Create New Chat", "Delete selected chat").
            They are all non-buffer_local today, which is the only reason the guard holds, and
            nothing asserts that. A hand-rolled vim.keymap.set with no desc — the exact failure
            the guard exists to catch — is invisible. Separately, running the leak test with
            chat_spell = { typeahead = true } fails on '<CR> (parley: accept spell suggestion /
            newline)', a map config.lua:337 and the atlas explicitly bless as a third category
            the allowance list omits. 2nd in family. Rule: an oracle must not depend on a
            property the code does not enforce — snapshot the buffer keymaps before prep and
            diff, or assert the desc convention; then add the feature-gated category to the list.
          family: test-harness-assumption
          round: 9
        - id: BR-40
          severity: Important
          title: '"every binding disableable" and ":map shows no parley mapping" are pinned over hand-narrowed subsets'
          detail: |-
            keybindings_spec.lua:472,501,513 exclude every dotted config_key (15 of 81 picker
            entries) with a typed `not e.config_key:find(".")`; keybinding_agreement_spec.lua:139
            checks only nvim_buf_get_keymap, never nvim_get_keymap. Both behaviours are in fact
            correct — I verified all 15 dotted entries disable via a nested config build, and
            that globals add nothing with the switch off — so this is coverage, not a bug.
            4th recorded in family (5th counting round 8's I1, lost to the protocol error).
            Rule restated: a promise quantified over a set must be pinned by a test that derives
            the set; a filter removing members is an allowlist wearing a predicate. Enumeration:
            build the nested table for dotted keys instead of skipping; assert the global keymap
            table alongside the buffer one. Third in-window instance: single_source_sweeps_spec
            .lua:66-72's fallback comment claims it "keeps historical coverage rather than
            silently passing", but on main merge-base==HEAD, the diff is empty, and it passes
            vacuously.
          family: docs-assert-unverified-behavior
          round: 9
        - id: BR-41
          severity: Important
          title: leaving interview mode deletes the user's own global insert-mode <CR> map
          detail: |-
            interview.lua:94-99 does an unconditional vim.keymap.del("i", "<CR>"). Measured: a
            user map on i <CR>, then setup_keymap() then remove_keymap(), leaves no map at all.
            <C-n>i followed by <C-n>I destroys a cmp/blink user's accept key for the session —
            the exact collision the Spec names and the Done-when's <CR> clause covers. The
            carve-out at config.lua:337 decides it is "the feature, not a default" but never asks
            whether removal is safe. Code is outside the diff window; operator's call whether it
            lands here, in M3, or at close. 2nd in family. Rule: a keymap serving a buffer-scoped
            feature must be installed buffer-locally, because a global install makes teardown
            destructive — del cannot distinguish mine from theirs. Buffer-local fixes it for
            free. interview.setup_keymap is the only global feature map left; spell.attach is
            already buffer-local.
          family: command-not-scoped-to-context
          round: 9
        - id: BR-42
          severity: Important
          title: the milestone's headline spec and M1's pure module are absent from atlas/traceability.yaml
          detail: |-
            atlas/traceability.yaml:689-696 maps ui/keybindings to keybindings_spec.lua and
            config_tools_spec.lua only. Missing: tests/integration/keybinding_agreement_spec.lua,
            lua/parley/branch_ref.lua and tests/unit/branch_ref_spec.lua (zero occurrences of
            "branch_ref" in the file), and the new #214 arch guards. Consequence: make
            test-changed after editing atlas/ui/keybindings.md — the doc this milestone rewrote —
            runs neither the agreement spec nor the new guards. No guard references
            traceability.yaml, which is why it drifts; M1's BR-2 flagged the same gap and only
            its test half was closed.
          family: artifact-missing-from-its-index
          round: 9
        - id: BR-43
          severity: Minor
          title: key_hint is defined twice verbatim in init.lua
          detail: |-
            init.lua:3306 and init.lua:4648 carry identical bodies and identical five-line
            comments. It replaced a `primary` helper that was also duplicated at those two sites,
            so the fix preserved the duplication rather than retiring it. Measured: the only
            byte-identical duplicated local in lua/. 5th in family. Rule: a helper needed at two
            call sites in one module is one module-scope helper; do not copy the body to keep the
            diff local.
          family: duplicate-helper-not-retired
          round: 9
        - id: BR-44
          severity: Minor
          title: key_for's new nil return reaches string.format at two of three picker title sites
          detail: |-
            issue_finder.lua:451 and note_finder.lua:388-389 pass a possibly-nil key straight to
            string.format("%s"), rendering "Issues (open  nil: cycle view)" and "Note Files
            (3 months  nil/nil: cycle)" under default_keymaps = false. chat_finder.lua:634-635
            guards the same value with `or "-"`. Same sweep, three sites, two conventions. Rule:
            when a helper's return type gains nil, every consumer must be updated, not only the
            ones that would crash.
          family: nullable-return-not-handled
          round: 9
        - id: BR-45
          severity: Minor
          title: the new arch guard reports roughly doubled line numbers
          detail: |-
            single_source_sweeps_spec.lua:473 iterates with gmatch("[^\n]*"), which yields an
            empty match after every line. Measured: a planted violation at
            system_prompt_picker.lua:121 was reported as :223. Use
            for line in (body.."\n"):gmatch("(.-)\n").
          family: diagnostic-cites-wrong-location
          round: 9
        - id: BR-46
          severity: Minor
          title: a malformed shortcut value silently disables the binding
          detail: |-
            keybinding_registry.lua:1019 — shortcut = 5 or shortcut = true falls through as_list
            to nil and disables the entry; before M2 it fell back to default_key. 2nd in family.
            Rule: parse the config value into a typed result at the boundary and degrade visibly
            (log and fall back), rather than mapping every unrepresentable shape onto a legal one.
            Related surface gaps, same round: README's "Changed defaults (upgrading)" table omits
            that shortcut = "" changed meaning from fall-through to disable, and
            chat_shortcut_delete_file is the one new config key neither README nor
            atlas/ui/keybindings.md mentions.
          family: illegal-state-representable-in-signature
          round: 9
      boundary: M2
      blocked: true
    - "n": 10
      timestamp: "2026-09-07T15:29:49-07:00"
      agent: claude
      dispose:
        - id: BR-38
          disposition: addressed
          note: Verified red twice by reversion — removing revoke_global_maps() fails two switch tests; removing the desc guard fails the "user rebound" test.
          round: 10
        - id: BR-39
          disposition: addressed
          note: 'Planted a desc-less vim.keymap.set in prep_chat: five tests red. Emptying feature_gated reds the typeahead-on leak test.'
          round: 10
        - id: BR-40
          disposition: addressed
          note: Forcing dotted config lookups to nil reds both the disable and rebind loops over all 81 entries; the 000205 fallback now reports pending instead of passing vacuously.
          round: 10
        - id: BR-41
          disposition: addressed
          note: Verified red by reverting to the global map — but the rescope introduced two new collisions, raised as a new finding in the same family.
          round: 10
        - id: BR-42
          disposition: addressed
          note: Removing keybinding_agreement_spec.lua from traceability.yaml reds the new guard; branch_ref module and specs are routed.
          round: 10
        - id: BR-43
          disposition: addressed
          note: One module-scope key_hint at init.lua:1527. Unpinned (a pure move); the family still has no enforcement — see Minor.
          round: 10
        - id: BR-44
          disposition: addressed
          note: 'Three title sites now use key_label. No test pins the "-" fallback: the existing title specs stay green if reverted.'
          round: 10
        - id: BR-45
          disposition: addressed
          note: Verified — a planted .shortcut read at system_prompt_picker.lua:121 is now reported as :121, not :223.
          round: 10
        - id: BR-46
          disposition: addressed
          note: Verified red by reverting the malformed branch — but the warning fires at every resolution rather than at the boundary; see new finding.
          round: 10
      findings:
        - id: BR-47
          severity: Important
          title: the interview <CR> rescope destroys parley's own spell map and confines interview mode to one buffer
          detail: |-
            Measured at HEAD. spell.attach then interview.setup_keymap then remove_keymap leaves the
            buffer with NO <CR> map: interview's buffer-local map overwrites spell's, and the del
            removes the slot. Separately, interview_start/stop are global maps and the mode flag,
            timer and lualine indicator are session state, but the effect is now installed on one
            buffer — open a second note and <CR> silently stops inserting timestamps while the
            statusline still says the mode is on. 3rd in family. Rule: del cannot distinguish "mine"
            from "theirs" at ANY scope, so narrowing global to buffer-local moved the collision
            rather than removing it; a feature map must be installed at the same scope as the state
            it serves and must tear down by RESTORING what it shadowed (capture maparg before
            setting, re-apply after) or by routing both features through one owned dispatcher, as
            base_cr already does. Enumeration, three collisions on one slot: interview vs spell's
            buffer-local <CR> (measured, destructive), interview vs a user's buffer-local <CR>
            (same mechanism, e.g. nvim-autopairs), and the global mode flag vs the per-buffer effect
            (measured, silent). If the narrowing is kept deliberately it needs a Revisions entry and
            a two-buffer test.
          family: command-not-scoped-to-context
          round: 10
        - id: BR-48
          severity: Important
          title: README's "every knob is named in config.lua" is false for 2 of 81 knobs
          detail: |-
            README.md:275-277 replaced the per-knob list with a universal claim. Enumerated all 81
            config_keys against lua/parley/config.lua — global_shortcut_vision_allocation and
            agent_picker_mappings.expand_catalog appear nowhere in that file (zero grep hits outside
            keybinding_registry.lua). Both still resolve from default_key, so this is
            discoverability, not breakage. 5th in family across four rounds. Rule restated: a
            user-facing promise quantified over a set must be pinned by a test that DERIVES the set
            from the source. Enumeration is one loop beside the existing "commands the README names"
            test — for each entry, assert its config_key appears in config.lua (table plus leaf for
            a dotted key). Fix the missing derived assertion, not the two knobs.
          family: docs-assert-unverified-behavior
          round: 10
        - id: BR-49
          severity: Important
          title: the malformed-shortcut warning fires at every resolution instead of parsing once at the boundary
          detail: |-
            keybinding_registry.lua:995-1004 calls parley.logger.warning, which appends to the log
            file and schedules a vim.notify popup (logger.lua:88-101). Measured with
            chat_shortcut_respond = { shortcut = 5 }: one warning per help_lines call and one per
            register_buffer pass — i.e. a popup on every chat/markdown BufEnter and every <C-g>?
            press, all session. Two consequences: resolve_keys is listed under "Pure entities" in
            the issue's Core concepts and now performs file IO plus a UI notification (ARCH-PURE),
            and repeated notify plus file-append sits on the buffer-prep path (ARCH-CONSTRAINTS).
            3rd in family. The rule was stated by the finding that produced this fix — parse the
            config value into a typed result AT THE BOUNDARY — and the fix validates at every read
            instead. Enumeration: every shape resolve_keys tolerates by coercion (number/boolean
            shortcut, non-table cfg_val for a dotted key, a list containing non-strings, still
            filtered silently at :1008) should be reported once in setup() beside the
            _explicit_shortcuts walk, leaving resolve_keys with no logger dependency.
          family: illegal-state-representable-in-signature
          round: 10
        - id: BR-50
          severity: Important
          title: two of this round's oracles still trust an input the code does not verify
          detail: |-
            Both measured. (1) keybinding_agreement_spec.lua:474 "a fresh setup with the switch off
            installs no global map" takes its baseline after ~13 earlier setup() calls in the same
            file. Planting vim.keymap.set("n", "<C-g>ZQ", ...) before the register_global call left
            the whole file GREEN; the identical assertion in an isolated spec goes red on the same
            plant. The spec's own comment at :79-82 states this rule correctly for buffers.
            (2) feature_gated (keybinding_registry.lua:1080) is trusted by both leak tests with
            nothing asserting its members are gated or documented — native_overrides has both guards,
            this has neither, and the "absent until the feature is on" check hand-types <CR> instead
            of iterating the table. 3rd in family. Rule: an oracle has two unverified inputs, its
            BASELINE and its ALLOWANCE LIST, and each must be derived from a state the subject has
            not touched, or asserted. Enumeration: take the global baseline per-test the way the
            buffer fixtures do; give feature_gated the two guards native_overrides has; and make the
            new traceability guard (:588, keyed off git merge-base HEAD main, so vacuous on main)
            report pending off a branch — the same fix applied two hunks earlier to the 000205
            fallback.
          family: test-harness-assumption
          round: 10
        - id: BR-51
          severity: Minor
          title: init.lua and spell.lua still describe interview's <CR> as a global map
          detail: |-
            init.lua:2284-2285 and spell.lua:167-169 both say spell's buffer-local map "shadows
            interview's global <CR> map", which is the load-bearing explanation for base_cr existing
            at all. After BR-41 both maps are buffer-local on the same buffer and neither shadows the
            other. 3rd in family. Rule: a comment that explains why a mechanism is SAFE must be
            re-read when the mechanism moves.
          family: stale-comment-after-move
          round: 10
        - id: BR-52
          severity: Minor
          title: three near-identical known-set/diff blocks in the agreement spec
          detail: |-
            keybinding_agreement_spec.lua:124-136, :146-158 and :318-328 each rebuild `known` from
            reg.entries plus native_overrides (plus feature_gated in two of the three) and then diff.
            6th in family; the rule has been stated each round and there is still no enforcement. A
            known_keys(cfg) local in this spec is the cheap fix, a guard over duplicated adjacent
            blocks is the class fix.
          family: duplicate-helper-not-retired
          round: 10
      boundary: M2
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

## Round 3 — 2026-09-06T09:31:47-07:00 (claude) — BLOCKED

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 4 — 2026-09-06T09:55:45-07:00 (claude) — BLOCKED

### Disposed

- BR-2 — not-addressed — Tests now exist (branch_ref_spec, 9 assertions, no IO); atlas/traceability.yaml:141-150 still lists only the four old files, so branch_ref.lua and both new specs route nowhere under make test-changed.
- BR-4 — not-addressed — Chat site fixed (branch_ref = chat_branch); init.lua:2551-2557 still rebuilds n/i/v wrappers for markdown, so .i remains dead at zero call sites.
- BR-5 — addressed — All full-line formatter sites route through branch_ref.format_ref_line; the arch guard at single_source_sweeps_spec.lua:378 is real.
- BR-10 — not-addressed — Code fix is correct and reachable, but reverting parent_ref to the bare basename leaves the FULL suite green — measured in a git clone.
- BR-11 — not-addressed — config_tools_spec.lua:436-447 still asserts only is_function plus registry-entry existence; reverting the callback to an inline closure leaves the full suite green — measured.
- BR-15 — addressed — No .lua:NNNN citation from this range survives in atlas/; the one code citation added (chat_respond.lua:1934) is accurate — verified.
- BR-17 — not-addressed — Guard added but no spec invokes ToggleToolFolds; deleting the guard leaves the full suite green — measured. Warning text says "chat buffers only" while markdown satisfies the guard.
- BR-18 — not-addressed — M._branch_inserters seam exists and specs now drive it, but nothing observes the stopinsert -> schedule(edit/G/startinsert!) interleaving; branch_child_spec also leaves two unflushed schedules while after_each deletes the tmpdir.
- BR-19 — addressed — Mutation-verified in a clone: removing the plain-path commit, the inline commit, or the scope guard each turns branch_child_spec red. The markdown residue is raised separately, not as BR-19.
- BR-20 — not-addressed — Measured this round: BR-10, BR-11, BR-17 and BR-21 each revert clean with the full suite green; the issue's Log names no per-finding test.
- BR-21 — not-addressed — init.lua:4586 uses a function replacement correctly, but branch_ref_spec.lua:53-67 re-implements the gsub in the test body; reverting to string concat leaves the full suite green — measured.
- BR-22 — not-addressed — .gitignore entry landed and HEAD's tree is clean, but 8ade807 still carries the four blobs (14 KB log with secret = "parley-local" and absolute paths); they reach main unless the branch is squashed or rebased.
- BR-23 — not-addressed — Both atlas instances swept, but the rule half was not delivered — no guard row asserts a doc names resolve_keys(entry, config)[1]; the row that landed guards the branch-ref formatter instead.
- BR-24 — not-addressed — keybinding_registry.lua:478 still duplicates config.lua's list byte-for-byte with nothing asserting they agree.
- BR-25 — not-addressed — keybindings_spec.lua:349 is still dofile("lua/parley/config.lua"), CWD-relative.
- BR-26 — not-addressed — branch_ref_spec has no case for a selection containing "](" nor for one ending mid-codepoint.

### Raised

- **BR-27** [Critical] `merged-path-loses-original-effect` Markdown normal/insert branch lost its cursor move and startinsert — the key now appears to do nothing
  commit_reference() returns false on any non-chat buffer and insert_plain
  treats that as "do not navigate" and returns, but the pre-#214 markdown
  path did not navigate either — it moved the cursor onto the new ref line
  and scheduled startinsert! so the user could type the topic. Measured
  through the real keymap: base 54a5c7a2 leaves cursor {3,34} with
  startinsert! queued and chat_dir empty; HEAD leaves cursor {2,0} in normal
  mode with a child file created. The code comment claims it "keeps the
  pre-#214 behaviour"; it does not. No test observes the markdown path.
- **BR-28** [Important] `partial-effect-not-committed` On a markdown buffer the branch key creates a child on disk whose only reference is never committed
  This is the 2nd finding in this family. Do not fix the instance. Round 3's
  rule enumerated the dispatch table's MODES; the component's state space is
  modes x buffer types, and the markdown cell creates the durable artifact
  while committing nothing and navigating nowhere — the exact BR-19 shape,
  relocated. Restate the rule as: every cell of modes x buffer types either
  commits the reference or does not create the artifact. For markdown the
  cheap resolution is the second half.
- **BR-29** [Important] `docs-assert-unverified-behavior` atlas/chat/inline_branch_links.md says markdown opens the child and that the two buffer types differ only in link target
  This is the 3rd finding in this family. Do not fix the instance. Both
  claims at :6-19 are false at HEAD — markdown never opens the child and the
  types also diverge on parent-commit and navigation — and the atlas never
  records that branching now :writes the parent buffer at all. Round 3 stated
  the rule and broke it in the same commit that applied it to README, which
  is the signal the family needs a mechanism: sweep every effect verb
  ("creates", "opens", "writes", "saves", "renames", "only") added by
  git diff --name-only <base> HEAD -- atlas/ README.md before the closing
  commit, and pin the surviving claims with a spec that exercises them.
  README is correctly scoped to "In Chat Buffer" and is fine.
- **BR-30** [Important] `plan-not-revised-after-decision-change` The issue Plan still states three superseded M1 decisions and has no Revisions section
  Row 1 names global_shortcut_branch_ref and the order {<M-S-CR>, <M-i>,
  <C-g>i}; the code ships chat_shortcut_branch_ref with <M-i> first. Row 3
  says "create immediately with an empty topic"; BR-1 established "?" and the
  code ships it. Row 2 is checked on "so the pair cannot drift again" while
  the markdown call site still re-implements .i and the two types diverge on
  three effects. AGENTS.md section 1 requires an appended "## Revisions"
  entry; the file has no such section, and this is the artifact the close
  gate's plan-unchecked guard reads.
- **BR-31** [Minor] `duplicate-helper-not-retired` chat_finder.lua:777 still hand-builds the inline branch-link format the new arch guard does not see
  This is the 4th finding in this family. Do not fix the instance. The guard
  at single_source_sweeps_spec.lua:378 matches one literal concatenation
  idiom (branch_prefix .. " " ..), which is why the sweep keeps missing
  siblings. The rule: key the guard on the emitted SHAPE — "](" adjacent to a
  .md path, and ": " after a prefix variable — not on one spelling of the
  concatenation.
- **BR-32** [Minor] `partial-effect-not-committed` commit_reference discards the write error, and the success log line fires before the committed check
  init.lua:2114-2119 pcalls the write and drops the error, so a failure
  reports "could not save the parent" with no cause. init.lua:2148 logs
  "Created branch to new chat: <file>" before the committed check, announcing
  success on the path where nothing was committed and nothing opened.

## Round 5 — 2026-09-06T10:18:15-07:00 (claude) — passed

### Disposed

- BR-2 — not-addressed — Spec landed; atlas/traceability.yaml still has no branch_ref.lua, branch_ref_spec or branch_child_spec, so make test-changed routes the new module nowhere.
- BR-4 — not-addressed — Chat site now passes the table through; init.lua:2570-2577 still re-implements .i around md_branch.n.
- BR-10 — not-addressed — Measured: reverting parent_ref to the plain basename leaves branch_child_spec 7/0/0; the only path reaching the fallback is the markdown-visual cell BR-28 says must not create a child.
- BR-11 — not-addressed — Measured: restoring the inline closure leaves config_tools_spec 26/0/0 and keybindings_spec 30/0/0; the added assertion checks the registry entry exists, not the identity.
- BR-17 — not-addressed — Measured: deleting the _parley_bufs guard from M.cmd.ToggleToolFolds leaves both specs green; no test enters it.
- BR-18 — not-addressed — .i() is driven now, but nothing drains or orders the scheduled startinsert!/edit, so no interleaving is observable.
- BR-20 — not-addressed — Measured prevalence this round is 4/4 - BR-10, BR-11, BR-17 and BR-21 all revert clean with the suite green; no Log line names a red test per finding id.
- BR-21 — not-addressed — branch_ref_spec.lua:53-66 runs the fixed gsub inside the test body; reverting init.lua's function replacement leaves branch_ref_spec 9/0/0 and branch_child_spec 7/0/0.
- BR-22 — addressed — Files removed in f617b96 and .gitignore carries .local/ with the cause; git ls-files shows none at HEAD.
- BR-23 — not-addressed — lifecycle.md and format.md were swept, but the guard row the rule called for was not added to single_source_sweeps_spec.lua.
- BR-24 — not-addressed — keybinding_registry.lua:478 and config.lua:362 still carry the same list with nothing asserting they agree.
- BR-25 — not-addressed — keybindings_spec.lua:331 still dofiles a CWD-relative path.
- BR-26 — not-addressed — No case for a selection containing "](" in branch_ref_spec.
- BR-27 — addressed — Pinned by branch_child_spec.lua:157-176 (cursor on the new line); the scheduled startinsert! half is still unasserted, which is BR-18.
- BR-28 — not-addressed — Reproduced at HEAD: on a foreign markdown buffer insert_inline (init.lua:2199-2204) creates the child and commit_reference returns false without writing - the rule was applied to n/i only.
- BR-29 — not-addressed — inline_branch_links.md:18 ("creates the child: no") contradicts :22 ("Visual mode ... creates the child") and the code follows :22; init.lua:2078-2082 still claims abs_link is the only difference and the topic is empty.
- BR-30 — not-addressed — Revisions section exists but records one of the three named deltas; Row 1's global_shortcut_branch_ref and Row 3's "empty topic" are still stated as shipped.
- BR-31 — not-addressed — chat_finder.lua:777 still hand-builds the inline link; the new guard matches only the `branch_prefix .. " " ..` idiom, not the emitted shape.
- BR-32 — not-addressed — Log ordering fixed; init.lua:2113 still discards the pcall error so a failed write reports no cause.

### Raised

- **BR-33** [Important] `state-rederived-instead-of-passed` branch_inserters reads ownership from the global M._parley_bufs at keypress instead of taking it from the call site that already knows
  init.lua:2110 and :2137 derive owns_file from a map the highlighter maintains
  (highlighter.lua:1063,1078,1138), while abs_link - the lesser fact - is a
  parameter. Both call sites know statically: prep_chat runs only for chat
  buffers, setup_markdown_keymaps only for markdown. Consequences measured in
  this diff: insert_inline omits the check with no signature saying it must
  not (that is BR-28); branch_child_spec.lua:77 must poke private state to
  reach the chat path, so the test fakes the thing under test; and a cleared
  entry (BufUnload, handle reuse) silently degrades a real chat buffer to
  foreign behaviour - no child, no write, no navigation. Pass
  { abs_link = ..., owns_file = ... } from both call sites, then the
  guarantee table is enforced by the signature rather than by a comment.
  ARCH-ORDER, ARCH-MOCK.

## Round 6 — 2026-09-07T13:47:38-07:00 (claude) — passed

### Disposed

- BR-2 — not-addressed — branch_ref_spec ships and passes 7, but atlas/traceability.yaml:141-150 still lists only the four old code files and three old tests - branch_ref.lua, branch_ref_spec.lua and branch_child_spec.lua are all absent, so make test-changed still routes nothing to them.
- BR-4 — not-addressed — Chat passes the table through (init.lua:2391); init.lua:2584-2589 still rebuilds .i around md_branch.n, so half the pair hand-wires and the Plan row claiming "the pair cannot drift again" is still not true.
- BR-10 — addressed — Verified by revert: parent_ref -> bare parent_rel leaves branch_child_spec 11/1.
- BR-11 — not-addressed — Verified by revert for the 4th round: an inline closure at init.lua:2429 leaves config_tools_spec 26/0, keybindings_spec 30/0 and branch_child_spec 12/0. The new test asserts the registry ENTRY exists, not that its callback IS M.cmd.ToggleToolFolds.
- BR-17 — addressed — Verified by revert: removing the guard leaves branch_child_spec 11/1. Minor residual - the guard is `not M._parley_bufs[buf]`, so it also admits parley markdown buffers while the warning says "chat buffers only".
- BR-18 — not-addressed — M._branch_inserters is a call seam, not an ordering seam. Nothing flushes or observes the schedule(edit -> G -> startinsert!), and the run leaks it - E211 "File .../plain-notes.md no longer available" plus three log lines printed after the suite summary.
- BR-20 — not-addressed — Improved but not in force. Measured this round 4/6 pin (BR-10, BR-17, BR-21, BR-28 all go red on revert); BR-11 and BR-33 revert clean. The issue's Log still names no test per finding id - those statements live only in the commit body.
- BR-21 — addressed — Verified by revert: string concat leaves branch_child_spec 10/2. The site is fixed and pinned; the CLASS is not - see the new finding.
- BR-23 — not-addressed — Instances swept (verified - only alias mentions remain in README/ARCH/atlas/lua). The rule half was not delivered: no guard row asserts a doc names only keys in resolve_keys(entry, config); the one new arch row is about the branch-ref formatter.
- BR-24 — not-addressed — keybinding_registry.lua:478 and config.lua:362 still carry the same three-key list with nothing asserting they agree.
- BR-25 — not-addressed — keybindings_spec.lua:350 dofile("lua/parley/config.lua") is still CWD-relative.
- BR-26 — not-addressed — branch_ref_spec has no case for a selection containing "](", nor for one ending in a multibyte character.
- BR-28 — addressed — Verified by revert: restoring the direct create_child_chat in insert_inline leaves branch_child_spec 11/1. The six-cell spec iterates both axes and fires.
- BR-29 — not-addressed — The two named claims are gone, but three new unverified ones landed in the same file - :7 states the signature as branch_inserters(buf, abs_link) when it takes three params; :22 says visual mode "creates the child" unconditionally, contradicting the table four lines above for foreign markdown; the table's "after the keypress = opens the child" is false for the chat x visual cell, which stays in the parent; and :36 "Child gets a parent back-link" is false for the markdown full-line path, which routes through init.lua:3939 where the back-link is skipped for a non-chat source. No spec exercises any atlas or README claim, which is the rule half that keeps not shipping.
- BR-30 — not-addressed — Revisions records the chord order, the tool-fold decision and the buffer-type divergence. Two of BR-30's three named deltas are still missing - Row 1's global_shortcut_branch_ref (code ships chat_shortcut_branch_ref) and Row 3's "empty topic" (code ships "?"). Row 2 is still [x] on "so the pair cannot drift again" while init.lua:2584-2589 re-implements .i.
- BR-31 — not-addressed — chat_finder.lua:777 is unchanged and the guard at single_source_sweeps_spec.lua:381 still matches the literal `branch_prefix .. " " ..` idiom, so the inline shape splice_inline_link owns has no owner and no guard.
- BR-32 — not-addressed — The log-ordering half is fixed. init.lua:2126 still writes `local ok = pcall(...)`, dropping the cause. Sibling in the same function - init.lua:2218 logs "Created inline branch to new chat" on the foreign-markdown path where no child was created.
- BR-33 — addressed — Both call sites now pass ownership (init.lua:2296, :2565) and neither mode reads M._parley_bufs. Residual raised separately as a Minor - two independent booleans do not encode the guarantee table in the signature the way the finding asked. branch_child_spec.lua:77's poke is now vestigial.

### Raised

- **BR-34** [Important] `user-text-unescaped-in-lua-pattern` BR-21 was fixed at one site; four gsub-replacement siblings survive, one of them the child-creation path M1 routes markdown branches to
  This is the 2nd finding in family user-text-unescaped-in-lua-pattern. Do NOT fix the
  named instances - state the rule and sweep the enumeration in this round. Rule - a
  runtime string may never be the second argument to gsub/sub; use a function
  replacement or escape %. Enumeration is `grep -n ':gsub(' lua/parley/*.lua` filtered
  to non-literal replacements. Surviving at HEAD - init.lua:3936 and :4079 and :4241
  substitute a user topic into `{{topic}}`, init.lua:3272 substitutes initial_question.
  Measured in this repo's LuaJIT, which does NOT raise - "50% off" becomes "50 off",
  "%1 placeholder" becomes "{{topic}} placeholder", "100%" writes a NUL byte. So the
  failure is silent corruption of the child's topic header. init.lua:3936 is load-
  bearing for M1 - the atlas states that on a foreign markdown buffer "the child is
  created when the link is followed", and that is this call. init.lua:3930-3950 and
  :4060-4085 are two hand-rolled re-implementations of create_child_chat; collapsing
  them onto it fixes the class and the duplication together. ARCH-SECURE, ARCH-PURPOSE.
- **BR-35** [Minor] `illegal-state-representable-in-signature` branch_inserters takes two independent booleans that encode one bit, so two of the four representable states are illegal and untested
  init.lua:2090 - branch_inserters(buf, abs_link, owns_file). The two call sites pass
  exactly mirrored literals, (buf, false, true) at :2296 for chat and (buf, true, false)
  at :2565 for markdown, and branch_child_spec hand-writes the same pairs at five
  places. (true, true) and (false, false) are representable, mean nothing, and no test
  covers them. BR-33's stated purpose was that "the guarantee table is enforced by the
  signature rather than by a comment"; two independent booleans do not do that. Collapse
  to one tagged parameter - kind = "chat" | "foreign" - and derive both facts from it.
  ARCH-ORDER.

## Round 7 — 2026-09-07T14:02:24-07:00 (claude) — passed

### Disposed

- BR-2 — not-addressed — Tests shipped (branch_ref_spec, 7 cases, green); atlas/traceability.yaml:141-150 is unchanged, so branch_ref.lua and both new specs are still mapped nowhere.
- BR-4 — not-addressed — Chat site fixed (init.lua:2391 passes chat_branch directly); init.lua:2583-2589 still rebuilds the table and re-implements `stopinsert; .n()`, which is verbatim `.i`.
- BR-11 — not-addressed — Verified by revert - replacing chat_toggle_tool_folds with an inline closure leaves config_tools_spec at 26/26. The new assertions check is_function and registry membership, never callback identity.
- BR-18 — not-addressed — M._branch_inserters exists and is used, but no test observes or injects the stopinsert -> schedule(edit + startinsert!) interleaving.
- BR-20 — not-addressed — Rule not built. Measured this round - BR-11 reverts clean, and the round's own init.lua:3272 gsub fix reverts clean with the arch and integration specs green. No per-finding-id test line in the Log.
- BR-23 — not-addressed — Both named doc lines swept, but the required guard row (no doc names a key that is not resolve_keys(entry, config)[1]) was not added to single_source_sweeps_spec.lua. The guard was the deliverable.
- BR-24 — not-addressed — keybinding_registry.lua:478 still duplicates config.lua:362 with nothing asserting agreement.
- BR-25 — not-addressed — keybindings_spec.lua:350 unchanged. Three pre-existing specs share the idiom, so the fix belongs in a shared repo-root helper.
- BR-26 — not-addressed — branch_ref_spec still has no case for a selection containing "](".
- BR-29 — not-addressed — Named claims corrected, rule not built, and two new false claims shipped in the same commit - atlas:7 states a 2-arg signature (3 params at HEAD) and atlas:20 states "opens the child" for the chat column, false for visual mode since create_child_chat only writes the file.
- BR-30 — not-addressed — Revisions records the chord order, tool-fold decision and buffer-type divergence. Row 1's global_shortcut_branch_ref (no such key exists) and Row 3's "empty topic" (code ships "?") are still stated as shipped.
- BR-31 — not-addressed — chat_finder.lua fixed; the guard at single_source_sweeps_spec.lua:388 still matches the literal `branch_prefix .. " " ..` idiom rather than the emitted shape.
- BR-32 — not-addressed — Log ordering IS fixed. init.lua:2126 still drops pcall's error, so "could not save the parent" ships with no cause.
- BR-34 — not-addressed — Four init.lua sites fixed, but issues.lua:662,663,665 - inside the finding's own `lua/parley/*.lua` enumeration - still pass runtime strings; the guard catches 1 of 5 planted shapes and misses the `or ""` form that is the live violation.
- BR-35 — not-addressed — Signature is still branch_inserters(buf, abs_link, owns_file); (true,true) and (false,false) remain representable and untested.

### Raised

- **BR-36** [Important] `no-seam-for-ordering` On a foreign markdown buffer the debounced refresh appends a warning to the line the user is typing the topic into
  This is the 2nd finding in family no-seam-for-ordering. Do NOT fix the
  instance - state the rule. insert_plain calls highlight_chat_branch_refs
  before the non-owned early return (init.lua:2170), arming the 500ms
  debounce at highlighter.lua:816. No child is created on that path, so
  render_chat_branch_line sees filereadable == 0 and rewrites the line with
  " warning-emoji" appended after whatever the user has typed, in insert
  mode. Measured - immediately the line is the bare ref, after typing it is
  "topic", after 900ms it is "topic + warning". It does not accumulate
  across five refreshes. The behaviour predates #214, but this milestone
  re-blessed the path as a stated guarantee (atlas table row "cursor on the
  new line, insert mode") and pinned it with branch_child_spec:181-204,
  which asserts only the synchronous state and therefore passes while the
  settled line differs. Rule - a branch path that arms a timer or schedules
  an effect is not pinned by a test asserting the buffer immediately after
  the call; the test must advance past the debounce and assert the settled
  line. That rule is enumerable over every vim.schedule and every
  highlight_chat_branch_refs call in the branch paths.
- **BR-37** [Minor] `scratch-artifact-swept-into-commit` c8cccd0 swept 462 lines of unrelated workshop/parley transcripts into a commit whose subject is a #220 process-leak filing
  This is the 2nd finding in family scratch-artifact-swept-into-commit. Do
  NOT fix the instance - state the rule. BR-22's fix was a .gitignore rule
  for .local/, which cannot generalize to this case - workshop/parley
  transcripts are wanted, tracked artifacts that landed in the wrong commit,
  so no ignore rule reaches them. The rule is staging discipline - stage the
  enumerated paths the commit subject names, never `git add -A`, and if a
  commit carries anything outside its issue's touch set, name it in the body.

## Round 8 — 2026-09-07T14:33:09-07:00 (claude) — passed

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 9 — 2026-09-07T15:05:18-07:00 (claude) — BLOCKED

### Raised

- **BR-38** [Important] `no-seam-for-ordering` default_keymaps = false does not revoke global maps installed by an earlier setup()
  Measured by keymap diff: setup() then setup({default_keymaps=false}) leaves 43
  global parley mappings live (<C-G>c/f/w, all <C-J>*, <C-N>*, <C-Y>*). register_global
  samples the switch once and has no teardown. config.lua:340 and atlas/ui/keybindings.md
  describe the limitation as buffer-local only, so the docs do not cover this.
  3rd in family: round 8 raised the buffer half as a Minor; the fix addressed buffers
  and never revisited the other sample site. Rule: every site that samples
  default_keymaps makes the decision durable, so each needs a stated reversibility rule
  and an assertion. Enumeration: register_global (setup-time, no teardown),
  register_buffer via prep_chat/setup_markdown_keymaps (_prepared_bufs-guarded),
  native_map (init.lua:2341, same guard).
- **BR-39** [Important] `test-harness-assumption` the no-leaks guard detects parley maps by a desc convention nothing enforces
  keybinding_agreement_spec.lua:71-79 filters on desc containing "parley". 46 of 81
  registry entries have descs that do not ("Create New Chat", "Delete selected chat").
  They are all non-buffer_local today, which is the only reason the guard holds, and
  nothing asserts that. A hand-rolled vim.keymap.set with no desc — the exact failure
  the guard exists to catch — is invisible. Separately, running the leak test with
  chat_spell = { typeahead = true } fails on '<CR> (parley: accept spell suggestion /
  newline)', a map config.lua:337 and the atlas explicitly bless as a third category
  the allowance list omits. 2nd in family. Rule: an oracle must not depend on a
  property the code does not enforce — snapshot the buffer keymaps before prep and
  diff, or assert the desc convention; then add the feature-gated category to the list.
- **BR-40** [Important] `docs-assert-unverified-behavior` "every binding disableable" and ":map shows no parley mapping" are pinned over hand-narrowed subsets
  keybindings_spec.lua:472,501,513 exclude every dotted config_key (15 of 81 picker
  entries) with a typed `not e.config_key:find(".")`; keybinding_agreement_spec.lua:139
  checks only nvim_buf_get_keymap, never nvim_get_keymap. Both behaviours are in fact
  correct — I verified all 15 dotted entries disable via a nested config build, and
  that globals add nothing with the switch off — so this is coverage, not a bug.
  4th recorded in family (5th counting round 8's I1, lost to the protocol error).
  Rule restated: a promise quantified over a set must be pinned by a test that derives
  the set; a filter removing members is an allowlist wearing a predicate. Enumeration:
  build the nested table for dotted keys instead of skipping; assert the global keymap
  table alongside the buffer one. Third in-window instance: single_source_sweeps_spec
  .lua:66-72's fallback comment claims it "keeps historical coverage rather than
  silently passing", but on main merge-base==HEAD, the diff is empty, and it passes
  vacuously.
- **BR-41** [Important] `command-not-scoped-to-context` leaving interview mode deletes the user's own global insert-mode <CR> map
  interview.lua:94-99 does an unconditional vim.keymap.del("i", "<CR>"). Measured: a
  user map on i <CR>, then setup_keymap() then remove_keymap(), leaves no map at all.
  <C-n>i followed by <C-n>I destroys a cmp/blink user's accept key for the session —
  the exact collision the Spec names and the Done-when's <CR> clause covers. The
  carve-out at config.lua:337 decides it is "the feature, not a default" but never asks
  whether removal is safe. Code is outside the diff window; operator's call whether it
  lands here, in M3, or at close. 2nd in family. Rule: a keymap serving a buffer-scoped
  feature must be installed buffer-locally, because a global install makes teardown
  destructive — del cannot distinguish mine from theirs. Buffer-local fixes it for
  free. interview.setup_keymap is the only global feature map left; spell.attach is
  already buffer-local.
- **BR-42** [Important] `artifact-missing-from-its-index` the milestone's headline spec and M1's pure module are absent from atlas/traceability.yaml
  atlas/traceability.yaml:689-696 maps ui/keybindings to keybindings_spec.lua and
  config_tools_spec.lua only. Missing: tests/integration/keybinding_agreement_spec.lua,
  lua/parley/branch_ref.lua and tests/unit/branch_ref_spec.lua (zero occurrences of
  "branch_ref" in the file), and the new #214 arch guards. Consequence: make
  test-changed after editing atlas/ui/keybindings.md — the doc this milestone rewrote —
  runs neither the agreement spec nor the new guards. No guard references
  traceability.yaml, which is why it drifts; M1's BR-2 flagged the same gap and only
  its test half was closed.
- **BR-43** [Minor] `duplicate-helper-not-retired` key_hint is defined twice verbatim in init.lua
  init.lua:3306 and init.lua:4648 carry identical bodies and identical five-line
  comments. It replaced a `primary` helper that was also duplicated at those two sites,
  so the fix preserved the duplication rather than retiring it. Measured: the only
  byte-identical duplicated local in lua/. 5th in family. Rule: a helper needed at two
  call sites in one module is one module-scope helper; do not copy the body to keep the
  diff local.
- **BR-44** [Minor] `nullable-return-not-handled` key_for's new nil return reaches string.format at two of three picker title sites
  issue_finder.lua:451 and note_finder.lua:388-389 pass a possibly-nil key straight to
  string.format("%s"), rendering "Issues (open  nil: cycle view)" and "Note Files
  (3 months  nil/nil: cycle)" under default_keymaps = false. chat_finder.lua:634-635
  guards the same value with `or "-"`. Same sweep, three sites, two conventions. Rule:
  when a helper's return type gains nil, every consumer must be updated, not only the
  ones that would crash.
- **BR-45** [Minor] `diagnostic-cites-wrong-location` the new arch guard reports roughly doubled line numbers
  single_source_sweeps_spec.lua:473 iterates with gmatch("[^\n]*"), which yields an
  empty match after every line. Measured: a planted violation at
  system_prompt_picker.lua:121 was reported as :223. Use
  for line in (body.."\n"):gmatch("(.-)\n").
- **BR-46** [Minor] `illegal-state-representable-in-signature` a malformed shortcut value silently disables the binding
  keybinding_registry.lua:1019 — shortcut = 5 or shortcut = true falls through as_list
  to nil and disables the entry; before M2 it fell back to default_key. 2nd in family.
  Rule: parse the config value into a typed result at the boundary and degrade visibly
  (log and fall back), rather than mapping every unrepresentable shape onto a legal one.
  Related surface gaps, same round: README's "Changed defaults (upgrading)" table omits
  that shortcut = "" changed meaning from fall-through to disable, and
  chat_shortcut_delete_file is the one new config key neither README nor
  atlas/ui/keybindings.md mentions.

## Round 10 — 2026-09-07T15:29:49-07:00 (claude) — BLOCKED

### Disposed

- BR-38 — addressed — Verified red twice by reversion — removing revoke_global_maps() fails two switch tests; removing the desc guard fails the "user rebound" test.
- BR-39 — addressed — Planted a desc-less vim.keymap.set in prep_chat: five tests red. Emptying feature_gated reds the typeahead-on leak test.
- BR-40 — addressed — Forcing dotted config lookups to nil reds both the disable and rebind loops over all 81 entries; the 000205 fallback now reports pending instead of passing vacuously.
- BR-41 — addressed — Verified red by reverting to the global map — but the rescope introduced two new collisions, raised as a new finding in the same family.
- BR-42 — addressed — Removing keybinding_agreement_spec.lua from traceability.yaml reds the new guard; branch_ref module and specs are routed.
- BR-43 — addressed — One module-scope key_hint at init.lua:1527. Unpinned (a pure move); the family still has no enforcement — see Minor.
- BR-44 — addressed — Three title sites now use key_label. No test pins the "-" fallback: the existing title specs stay green if reverted.
- BR-45 — addressed — Verified — a planted .shortcut read at system_prompt_picker.lua:121 is now reported as :121, not :223.
- BR-46 — addressed — Verified red by reverting the malformed branch — but the warning fires at every resolution rather than at the boundary; see new finding.

### Raised

- **BR-47** [Important] `command-not-scoped-to-context` the interview <CR> rescope destroys parley's own spell map and confines interview mode to one buffer
  Measured at HEAD. spell.attach then interview.setup_keymap then remove_keymap leaves the
  buffer with NO <CR> map: interview's buffer-local map overwrites spell's, and the del
  removes the slot. Separately, interview_start/stop are global maps and the mode flag,
  timer and lualine indicator are session state, but the effect is now installed on one
  buffer — open a second note and <CR> silently stops inserting timestamps while the
  statusline still says the mode is on. 3rd in family. Rule: del cannot distinguish "mine"
  from "theirs" at ANY scope, so narrowing global to buffer-local moved the collision
  rather than removing it; a feature map must be installed at the same scope as the state
  it serves and must tear down by RESTORING what it shadowed (capture maparg before
  setting, re-apply after) or by routing both features through one owned dispatcher, as
  base_cr already does. Enumeration, three collisions on one slot: interview vs spell's
  buffer-local <CR> (measured, destructive), interview vs a user's buffer-local <CR>
  (same mechanism, e.g. nvim-autopairs), and the global mode flag vs the per-buffer effect
  (measured, silent). If the narrowing is kept deliberately it needs a Revisions entry and
  a two-buffer test.
- **BR-48** [Important] `docs-assert-unverified-behavior` README's "every knob is named in config.lua" is false for 2 of 81 knobs
  README.md:275-277 replaced the per-knob list with a universal claim. Enumerated all 81
  config_keys against lua/parley/config.lua — global_shortcut_vision_allocation and
  agent_picker_mappings.expand_catalog appear nowhere in that file (zero grep hits outside
  keybinding_registry.lua). Both still resolve from default_key, so this is
  discoverability, not breakage. 5th in family across four rounds. Rule restated: a
  user-facing promise quantified over a set must be pinned by a test that DERIVES the set
  from the source. Enumeration is one loop beside the existing "commands the README names"
  test — for each entry, assert its config_key appears in config.lua (table plus leaf for
  a dotted key). Fix the missing derived assertion, not the two knobs.
- **BR-49** [Important] `illegal-state-representable-in-signature` the malformed-shortcut warning fires at every resolution instead of parsing once at the boundary
  keybinding_registry.lua:995-1004 calls parley.logger.warning, which appends to the log
  file and schedules a vim.notify popup (logger.lua:88-101). Measured with
  chat_shortcut_respond = { shortcut = 5 }: one warning per help_lines call and one per
  register_buffer pass — i.e. a popup on every chat/markdown BufEnter and every <C-g>?
  press, all session. Two consequences: resolve_keys is listed under "Pure entities" in
  the issue's Core concepts and now performs file IO plus a UI notification (ARCH-PURE),
  and repeated notify plus file-append sits on the buffer-prep path (ARCH-CONSTRAINTS).
  3rd in family. The rule was stated by the finding that produced this fix — parse the
  config value into a typed result AT THE BOUNDARY — and the fix validates at every read
  instead. Enumeration: every shape resolve_keys tolerates by coercion (number/boolean
  shortcut, non-table cfg_val for a dotted key, a list containing non-strings, still
  filtered silently at :1008) should be reported once in setup() beside the
  _explicit_shortcuts walk, leaving resolve_keys with no logger dependency.
- **BR-50** [Important] `test-harness-assumption` two of this round's oracles still trust an input the code does not verify
  Both measured. (1) keybinding_agreement_spec.lua:474 "a fresh setup with the switch off
  installs no global map" takes its baseline after ~13 earlier setup() calls in the same
  file. Planting vim.keymap.set("n", "<C-g>ZQ", ...) before the register_global call left
  the whole file GREEN; the identical assertion in an isolated spec goes red on the same
  plant. The spec's own comment at :79-82 states this rule correctly for buffers.
  (2) feature_gated (keybinding_registry.lua:1080) is trusted by both leak tests with
  nothing asserting its members are gated or documented — native_overrides has both guards,
  this has neither, and the "absent until the feature is on" check hand-types <CR> instead
  of iterating the table. 3rd in family. Rule: an oracle has two unverified inputs, its
  BASELINE and its ALLOWANCE LIST, and each must be derived from a state the subject has
  not touched, or asserted. Enumeration: take the global baseline per-test the way the
  buffer fixtures do; give feature_gated the two guards native_overrides has; and make the
  new traceability guard (:588, keyed off git merge-base HEAD main, so vacuous on main)
  report pending off a branch — the same fix applied two hunks earlier to the 000205
  fallback.
- **BR-51** [Minor] `stale-comment-after-move` init.lua and spell.lua still describe interview's <CR> as a global map
  init.lua:2284-2285 and spell.lua:167-169 both say spell's buffer-local map "shadows
  interview's global <CR> map", which is the load-bearing explanation for base_cr existing
  at all. After BR-41 both maps are buffer-local on the same buffer and neither shadows the
  other. 3rd in family. Rule: a comment that explains why a mechanism is SAFE must be
  re-read when the mechanism moves.
- **BR-52** [Minor] `duplicate-helper-not-retired` three near-identical known-set/diff blocks in the agreement spec
  keybinding_agreement_spec.lua:124-136, :146-158 and :318-328 each rebuild `known` from
  reg.entries plus native_overrides (plus feature_gated in two of the three) and then diff.
  6th in family; the rule has been stated each round and there is still no enforcement. A
  known_keys(cfg) local in this spec is the cheap fix, a guard over duplicated adjacent
  blocks is the class fix.

## Open findings

- **BR-2** [Important] `pure-extraction-without-tests` New pure module lua/parley/branch_ref.lua has zero tests and is absent from traceability.yaml
- **BR-4** [Important] `duplicate-helper-not-retired` branch_inserters(...).i is dead at zero call sites and the chat visual path double-Escs
- **BR-11** [Minor] `test-does-not-pin-the-fix` config_tools_spec.lua:434 asserts is_function, not the identity its title claims
- **BR-18** [Minor] `no-seam-for-ordering` insert_plain's stopinsert then schedule(edit + startinsert!) has no seam to inject or observe
- **BR-20** [Important] `test-does-not-pin-the-fix` Three of this round's fixes survive their own revert with the full suite green
- **BR-23** [Important] `readme-missing-for-changed-surface` The changed-key doc sweep stopped at README; two atlas files still name the superseded primaries
- **BR-24** [Minor] `duplicate-helper-not-retired` keybinding_registry.lua:478 duplicates config.lua:362's chord list with nothing asserting they agree
- **BR-25** [Minor] `test-harness-assumption` keybindings_spec.lua:331 dofile("lua/parley/config.lua") is CWD-relative
- **BR-26** [Minor] `pure-extraction-without-tests` branch_ref_spec has no case for a selection containing "](", which breaks the emitted markdown link
- **BR-29** [Important] `docs-assert-unverified-behavior` atlas/chat/inline_branch_links.md says markdown opens the child and that the two buffer types differ only in link target
- **BR-30** [Important] `plan-not-revised-after-decision-change` The issue Plan still states three superseded M1 decisions and has no Revisions section
- **BR-31** [Minor] `duplicate-helper-not-retired` chat_finder.lua:777 still hand-builds the inline branch-link format the new arch guard does not see
- **BR-32** [Minor] `partial-effect-not-committed` commit_reference discards the write error, and the success log line fires before the committed check
- **BR-34** [Important] `user-text-unescaped-in-lua-pattern` BR-21 was fixed at one site; four gsub-replacement siblings survive, one of them the child-creation path M1 routes markdown branches to
- **BR-35** [Minor] `illegal-state-representable-in-signature` branch_inserters takes two independent booleans that encode one bit, so two of the four representable states are illegal and untested
- **BR-36** [Important] `no-seam-for-ordering` On a foreign markdown buffer the debounced refresh appends a warning to the line the user is typing the topic into
- **BR-37** [Minor] `scratch-artifact-swept-into-commit` c8cccd0 swept 462 lines of unrelated workshop/parley transcripts into a commit whose subject is a #220 process-leak filing
- **BR-47** [Important] `command-not-scoped-to-context` the interview <CR> rescope destroys parley's own spell map and confines interview mode to one buffer
- **BR-48** [Important] `docs-assert-unverified-behavior` README's "every knob is named in config.lua" is false for 2 of 81 knobs
- **BR-49** [Important] `illegal-state-representable-in-signature` the malformed-shortcut warning fires at every resolution instead of parsing once at the boundary
- **BR-50** [Important] `test-harness-assumption` two of this round's oracles still trust an input the code does not verify
- **BR-51** [Minor] `stale-comment-after-move` init.lua and spell.lua still describe interview's <CR> as a global map
- **BR-52** [Minor] `duplicate-helper-not-retired` three near-identical known-set/diff blocks in the agreement spec
