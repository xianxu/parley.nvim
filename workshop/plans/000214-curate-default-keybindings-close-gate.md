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
    - "n": 11
      timestamp: "2026-09-07T16:15:14-07:00"
      agent: claude
      dispose:
        - id: BR-47
          disposition: addressed
          note: Verified by reversion — round 9's buffer-local shape reds both halves (spell's map destroyed; mode confined to one buffer); dropping the restore reds 3 more.
          round: 11
        - id: BR-48
          disposition: addressed
          note: Verified by reversion — removing the two knobs from config.lua reds the new derived assertion. See the Minor on its substring predicate.
          round: 11
        - id: BR-49
          disposition: not-addressed
          note: Headline fixed and pinned; two of the four shapes the finding enumerated still coerce silently — see N3.
          round: 11
        - id: BR-50
          disposition: addressed
          note: All three parts verified — global plant reds 3, feature_gated has both guards, traceability guard reds on a real branch when a spec is unrouted.
          round: 11
        - id: BR-51
          disposition: addressed
          note: Resolved by reverting the mechanism, so init.lua/spell.lua read true again — but the atlas and lessons.md were not swept back (N1).
          round: 11
        - id: BR-52
          disposition: not-addressed
          note: The three blocks at keybinding_agreement_spec.lua:141-146, :163-168, :334-338 are untouched this round.
          round: 11
      findings:
        - id: BR-53
          severity: Important
          title: atlas and lessons.md still teach the interview-<CR> design round 10 reversed
          detail: |-
            atlas/ui/keybindings.md:130 states "Interview's <CR> is buffer-local … del must never be aimed
            at a global map"; the shipped map is global (interview.lua:112) and round 10's own commit says
            del cannot distinguish ownership at ANY scope. workshop/lessons.md:1435 carries the same
            reversed claim as a RULE every agent reads at session start, so following it re-creates BR-47.
            4th in family. Rule — when a round reverses a prior round's decision, the artifacts that
            recorded it are part of the reversal's diff and are mechanically enumerable via
            `git show --stat` of the reversed commit: a84108a touched atlas/ui/keybindings.md,
            workshop/lessons.md, interview.lua and the issue; 5bc1a41 touched only the last two.
            Enumeration: the atlas paragraph, the lessons rule, and the missing ## Revisions / ## Log entry.
          family: stale-comment-after-move
          round: 11
        - id: BR-54
          severity: Important
          title: the new interview tests drive setup_keymap/remove_keymap, never enter/exit — and enter/exit raises
          detail: |-
            keybinding_agreement_spec.lua:420-508 exercises the two internal steps. Driving the real
            transition instead raises, measured through the production BufEnter path: interview.enter()
            then opening any chat file gives "Cannot deepcopy object of type userdata" at init.lua:1347
            (refresh_state) from init.lua:2310 (prep_chat), because start_timer stores a vim.loop handle in
            _state.interview_timer (interview.lua:193). Pre-existing and outside the window, so not a
            blocker on its own; it matters because round 10's rationale is "the map lives at the same scope
            as the session state it serves" and that state's lifecycle cannot currently run, and because the
            tests added this round are the ones that would have caught it. 4th in family. Rule — a lifecycle
            fix must be pinned through the transition the user triggers, not the internal step the fix
            edited. Enumeration: convert the six tests to enter()/exit() (both work headless), and keep the
            timer handle out of the deepcopied state.
          family: no-seam-for-ordering
          round: 11
        - id: BR-55
          severity: Minor
          title: _explicit_shortcuts is computed from raw opts before setup() strips malformed values
          detail: |-
            init.lua:546 walks the raw opts; the malformed-shortcut strip runs at :636. A knob whose value is
            later stripped stays marked explicit, so the master switch lets it through and it falls back to
            default_key. Measured — default_keymaps = false plus chat_shortcut_respond = { shortcut = 5 }
            binds <C-g><C-g>, a default key on a config that asked for none. Build the explicit set from the
            normalised config, or clear the entry when stripping.
          family: derive-before-validate
          round: 11
        - id: BR-56
          severity: Minor
          title: the BR-48 derived guard uses an unanchored substring, so 8 of 15 dotted knobs cannot fail it
          detail: |-
            keybinding_agreement_spec.lua:526 asserts shipped_src:find(leaf, 1, true). Leaf "delete" occurs
            11 times in config.lua, "move" 7, "next_recency" 3 — so deleting note_finder_mappings.delete,
            chat_finder_mappings.move and six siblings leaves the test green. 5th in family. Rule — a derived
            assertion must be member-discriminating: verify it by deleting one member at a time for EVERY
            member, not for the two the finding happened to name. Anchor the match to an assignment.
          family: test-does-not-pin-the-fix
          round: 11
        - id: BR-57
          severity: Minor
          title: README's "Every knob is named in config.lua" is swallowed into the preceding bullet
          detail: |-
            README.md:277 follows a list item with no blank line, so GFM lazy continuation renders this
            section-level claim as part of the `u`/`<C-r>` bullet.
          family: markdown-block-not-separated
          round: 11
      boundary: M2
      blocked: false
    - "n": 12
      timestamp: "2026-09-07T16:42:25-07:00"
      agent: claude
      boundary: M3
      blocked: false
      protocol_error: no valid findings block
    - "n": 13
      timestamp: "2026-09-07T18:11:18-07:00"
      agent: claude
      findings:
        - id: BR-58
          severity: Critical
          title: "the \U0001F33F: reference position is computed before the marker strip and used after it"
          detail: "init.lua:2336-2347 applies marker_edits, then inserts at plan.ref_after — the\nPRE-strip cursor line. apply_text_edits returns line_delta (buffer_edit.lua:203)\nand it is discarded; chat_respond.lua:1299 solves the same problem with\nbuffer_edit.make_handle. Reproduced three ways: a standalone \U0001F916[…] above the\ncursor (drill_in.lua:443-446 deletes the newline), a cursor on the last line,\nand a multi-line \U0001F916[a\\nb]. In the third the reference lands AFTER \U0001F4DD: the\nsummary — the relocation the operator revised the design twice to remove — and\nin the first the \"one blank line each side\" MARGIN invariant breaks (two before,\nzero after). The only quotes-case integration test uses an inline marker, whose\ndelta is zero, so it observes one interleaving and reports no coverage\n(ARCH-ORDER). Fix: anchor the cursor line with make_handle before\napply_text_edits and read it back, and add a standalone-marker fixture."
          family: stale-position-across-buffer-edit
          round: 13
        - id: BR-59
          severity: Critical
          title: the plan's and issue's Core concepts tables describe a plan_submission the code does not implement
          detail: |-
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
          family: plan-not-revised-after-decision-change
          round: 13
        - id: BR-60
          severity: Critical
          title: Task 7's <M-CR> agreement check is checked off but absent, and the equivalence it guarded is already false
          detail: "This is the 6th finding in family `docs-assert-unverified-behavior`. Earlier\nrounds fixed instances. Do not fix this instance alone — the rule is: a plan step\nmay not be checked off, and a `## Deviations` entry may not describe a test, until\nthat test exists in the tree and has been seen red; the mutation ledger is\ngenerated from `git diff <base> -- lua/` and a row whose mutation target is not in\nthe diff is a defect in the ledger, not a note.\nplan:314-320 checks off the agreement pin; `## Deviations` item 2 claims it \"runs\nplan_submission's exchange resolution against init.lua's find_exchange_at_line\nline-by-line over three transcripts. Verified by deleting the planner's margin\nrule: three tests go red.\" grep -rn find_exchange_at_line tests/ hits only\ntests/unit/pure_functions_spec.lua; plan_submission has no exchange resolution and\nno margin rule. Three ledger rows (case 3b delete_lines, ref lands after \U0001F4DD:,\nplanner agrees with find_exchange_at_line) mutate code that is not in the tree.\nThe unguarded promise is already broken twice: init.lua:2329 hardcodes\nbracket = true where chat_respond.lua:1284 reads config.mark_reference_span, and\n<M-i> gathers buffer-wide where <M-CR> gathers per-exchange\n(chat_respond.lua:1287-1294, :1336-1345) — so README.md:174,\natlas/chat/inline_branch_links.md:31 and branch_submit.lua:5-6 all assert an\nequivalence that does not hold."
          family: docs-assert-unverified-behavior
          round: 13
        - id: BR-61
          severity: Important
          title: the gf smart go-to-file bullet was deleted from README as collateral of the <M-i> rewrite
          detail: |-
            This is the 3rd finding in family `readme-missing-for-changed-surface`. Do not
            just restore the line — state the rule: README's binding list and the registry's
            resolved default keys must agree, and that agreement should be derived, not
            reviewed. M2 already built the machinery (keybinding_agreement_spec.lua, key_for)
            and already caught three README-documented commands that were never implemented;
            extend the same derivation to bindings so a bullet cannot vanish silently.
            `git show d5ba3eb:README.md` line 179 documents `gf`; it is absent at HEAD and
            `gf` is still shipped.
          family: readme-missing-for-changed-surface
          round: 13
        - id: BR-62
          severity: Important
          title: the new unit spec calls parley.setup() per test, and make test is red from a clean environment
          detail: |-
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
          family: test-harness-assumption
          round: 13
        - id: BR-63
          severity: Important
          title: create_child_chat is unguarded after the parent has already been stripped and the reference inserted
          detail: "This is the 4th finding in family `partial-effect-not-committed`. Do not guard\nthe one call — the rule is: within a single keypress transition, every effect\nafter the first buffer mutation is guarded the same way, and a failure states\nwhat the buffer is left holding. Right now the guarding is inconsistent within\nten lines of the same function.\ninit.lua:2350 calls create_child_if_owned bare while :2351 calls commit_reference,\nwhich pcalls its :write. By :2350 the markers are stripped and the \U0001F33F: line\ninserted, so a raise (unwritable chat_dir, full disk) escapes the keymap callback\nleaving a parent pointing at a file that does not exist. This is plan-gate finding\nPQ-8, still open at that gate, shipped unchanged."
          family: partial-effect-not-committed
          round: 13
        - id: BR-64
          severity: Important
          title: "\U0001F512: content previously withheld from the LLM is now submitted, with no upgrade note"
          detail: "atlas/chat/format.md documented \U0001F512: as a local SECTION excluded from LLM context;\nchat_parser.lua:606-613 makes it one line. A user whose transcripts used the\ndocumented semantics silently begins submitting every line after the first noted\none on their next request. The measurement cited (0 of 16 chats in the operator's\ncorpus) bounds the operator's exposure, not a published plugin's users. The atlas\nrecords the new behaviour; README has no upgrade or breaking-change section and\nnever documented the prefix, so there is nowhere a user would see this\n(ARCH-SECURE at-review)."
          family: breaking-change-without-upgrade-note
          round: 13
        - id: BR-65
          severity: Minor
          title: ready_marker_lines computes a line number per marker that plan_submission never reads
          detail: |-
            This is the 2nd finding in family `dead-value-in-new-code`. Do not just delete
            the field — the rule is: a value computed to satisfy a signature must be read by
            that signature's implementation, or the parameter goes away; a dead field in a
            "pure decision" module is what makes the module look like it decides more than it
            does. init.lua:2266-2278 counts newlines per ready marker to build { line = N };
            branch_submit.lua:87-101 only tests #markers > 0. The same pass also runs
            drill_in.parse over the whole buffer a second time — gather_edit_plan at :2329
            parses again.
          family: dead-value-in-new-code
          round: 13
        - id: BR-66
          severity: Minor
          title: annotation_line re-implements the classifier's predicate while its comment claims it reuses it
          detail: |-
            This is the 7th finding in family `duplicate-helper-not-retired`. Earlier rounds
            fixed instances. Do not fix this instance — the rule is: a line-kind predicate
            lives in highlight_structure beside the patterns it reads, and callers ask it
            rather than re-matching pattern fields; highlight_structure.is_partition
            (:180-198) is the precedent for exactly this. chat_parser.lua:335-342 defines
            annotation_line inline (rebuilt per finalize_component call) matching
            local_pattern/branch_pattern directly, under a comment asserting it reuses
            highlight_structure.classify. Add is_annotation(line, patterns) there and call it.
          family: duplicate-helper-not-retired
          round: 13
        - id: BR-67
          severity: Minor
          title: 'revision 11 was written into the middle of the M3 Plan bullet instead of into ## Revisions'
          detail: |-
            This is the 2nd finding in family `markdown-block-not-separated`. Do not just move
            this block — the rule is: a `## Revisions` entry is appended to `## Revisions`,
            never inlined into the artifact section it revises, and its number is unique
            across the issue.
            workshop/issues/000214-curate-default-keybindings.md:507 puts a `###` heading and
            its body between "Rows 2a/2b collapse" and "(placement is the cursor, not the
            exchange end)", severing the bullet and nesting a heading inside `## Plan`.
            `## Revisions` is at :764, and the numbered entries 1-11 are currently split
            across `## Plan`, `## Log` and `## Revisions` with 1/2/3 used twice.
          family: markdown-block-not-separated
          round: 13
      boundary: M3
      blocked: true
    - "n": 14
      timestamp: "2026-09-07T18:32:20-07:00"
      agent: claude
      dispose:
        - id: BR-58
          disposition: not-addressed
          note: |-
            make_handle takes a 0-indexed row but is passed the 1-indexed cursor line, so the
            anchor sits on the whitespace gap that drill_in.lua:457-458 swallows into its `]`
            edit; with left gravity the mark collapses and the ref lands ABOVE the cursor line.
            Reproduced: standalone marker directly below the cursor, and inline-above + standalone-below.
            Every new fixture puts the marker above the cursor, so the suite samples one side of the axis.
          round: 14
        - id: BR-59
          disposition: not-addressed
          note: |-
            Core-concepts tables corrected in both plan and issue and the ledger rows struck, but
            the plan's Task 3 steps are still `- [x]` over six assertions absent from the tree, and
            `## Deviations` still records no entry for the removal — two of the four artifacts the rule named.
          round: 14
        - id: BR-60
          disposition: not-addressed
          note: |-
            Task 7's body now says NOT DELIVERED and the ledger row is struck, but `## Deviations`
            item 2 still states verbatim that the check runs plan_submission's exchange resolution
            against find_exchange_at_line over three transcripts, verified by three red tests. No such test exists.
          round: 14
        - id: BR-61
          disposition: not-addressed
          note: |-
            The `gf` bullet is restored, but the derivation the finding asked for was not built —
            no test relates README's binding bullets to the registry's resolved default keys, so the
            next bullet can still vanish silently. Instance fixed, class open.
          round: 14
        - id: BR-62
          disposition: addressed
          note: |-
            setup() dropped from the new spec; two clean-environment `make test` runs green (200 files).
            The ensure_dir_exists half is unnecessary — measured that vim.fn.mkdir(existing, "p") returns
            1 without error on nvim 0.11.7, and every mkdir in lua/ passes "p".
          round: 14
        - id: BR-63
          disposition: addressed
          note: |-
            Create now precedes every buffer mutation and is pcall'd; branch_child_spec.lua:820-838
            simulates the failure and asserts the markers survive. See Minor M2 for the unswept half
            (the effects after the create are now the unguarded ones).
          round: 14
        - id: BR-64
          disposition: addressed
          note: |-
            README now carries an explicit upgrade note under "Two config contracts changed"; the atlas
            records the single-line semantics in both format.md and parsing.md.
          round: 14
        - id: BR-65
          disposition: addressed
          note: |-
            ready_marker_lines is gone (grep: zero hits) and the second drill_in.parse pass with it;
            the gather is now asked first and is the authority. See Minor M1 for the parse_chat that remains unconditional.
          round: 14
        - id: BR-66
          disposition: not-addressed
          note: |-
            The false comment is fixed and the closure hoisted out of finalize_component, but the
            predicate still re-matches local_pattern/branch_pattern in chat_parser instead of living in
            highlight_structure as is_annotation. A reasoned counter-argument is given in the comment; the stated rule is not followed.
          round: 14
        - id: BR-67
          disposition: not-addressed
          note: |-
            The block no longer severs the Plan bullet, but the rule was not applied: entries 9-11 still
            live under `## Log` rather than `## Revisions`, numbers 1/2/3 remain duplicated across the two
            sections, and the move stranded a two-line fragment at issue :647-648.
          round: 14
      findings:
        - id: BR-68
          severity: Important
          title: the "one blank line each side" margin is asserted in three artifacts and held by neither insert path
          detail: |-
            init.lua:2343-2345 inserts { "", ref } — one blank BEFORE only — under a comment claiming
            "one blank line each side"; insert_plain at :2387-2390 inserts the bare line with no blank on
            either side. The plan says `add_block(k, "branch_ref", 1, 1)` and no such block kind exists in
            exchange_model.lua. Measured: cursor line followed immediately by non-blank prose leaves the ref
            abutting the next line; the two-marker case leaves two blanks before it. The existing assertions
            (branch_child_spec.lua:397, 419-420) pass only because those fixtures happen to have a blank in the
            right place. Rule: an invariant stated in a comment or plan is pinned by a fixture that would violate
            it if the code were wrong — here, non-blank text on BOTH sides — and one key gets one spacing rule in one helper.
          family: docs-assert-unverified-behavior
          round: 14
        - id: BR-69
          severity: Important
          title: the pending-response refusal covers n and i but not v, while README and the atlas state it for the whole chord
          detail: |-
            init.lua:2288 guards insert_planned, reachable only from insert_plain (n/i). insert_inline at
            :2425-2452 runs create_child_if_owned and commit_reference with no check. README.md's closing
            paragraph ("It declines while a response is still streaming into that chat") and
            atlas/chat/inline_branch_links.md:60-62 ("Refusals. The chord declines...") both assert it for all
            three cases. init.lua:2216-2219 already states the governing rule for this file: the enumeration is
            the dispatch table n/i/v, not the path in front of you. Lift the guard above the dispatch table, or narrow both documents.
          family: docs-assert-unverified-behavior
          round: 14
        - id: BR-70
          severity: Important
          title: atlas/chat/drill_in.md still names chat_respond as the owner of the gather options
          detail: |-
            :130-137 read "chat_respond assembles them from config" and "opts.bracket (set by chat_respond from
            config.mark_reference_span)". The owner is now drill_in.chat_gather_opts with two consumers. The file
            is named in the plan's Task 8 file list and is absent from the diff — new surface with no update to its
            home atlas page (AGENTS.md section 8).
          family: stale-comment-after-move
          round: 14
        - id: BR-71
          severity: Minor
          title: a full parse_chat runs on every M-i press to answer only "are there zero exchanges"
          detail: |-
            init.lua:2296 parses the whole buffer (M.parse_chat is uncached, init.lua:3709) before the
            has_markers check that decides whether a plan is possible at all; on the common no-marker path the
            result is discarded. Ask the gather first, then parse only when a plan can exist. ARCH-CONSTRAINTS:
            this is an interactive keypress path now doing two full-buffer passes with no declared envelope.
          family: derive-before-validate
          round: 14
        - id: BR-72
          severity: Minor
          title: BR-63 moved the point of no return, and the effects after it are now the unguarded ones
          detail: |-
            This is the 5th finding in family `partial-effect-not-committed`. Earlier rounds fixed instances.
            Do not guard the one call — the rule BR-63 stated still has an unswept half: within a single keypress
            transition, every effect after the point of no return is guarded the same way and a failure states what
            the buffer is left holding. create_child_if_owned is now pcall'd and first (init.lua:2329); the
            apply_text_edits and nvim_buf_set_lines at :2337-2345 that follow it are not, so a raise there leaves a
            child on disk with no reference — BR-19's orphan by the reverse route. Low probability, since the edits are drill_in's own.
          family: partial-effect-not-committed
          round: 14
        - id: BR-73
          severity: Minor
          title: two plan_submission decline tests are green for reasons unrelated to their names
          detail: |-
            This is the 6th finding in family `test-does-not-pin-the-fix`. Do not fix these two — the rule is:
            a test's name states the branch it takes, and the assertion fails if that branch is removed.
            branch_submit_spec.lua:135-140 "a question with no text has nothing to submit" passes has_markers = false
            and plan_submission never inspects question.content, so it exercises the marker branch and would stay
            green if the content check it names were added and then broken. :129 passes `{}` (truthy) for a boolean
            parameter, a leftover from the pre-narrowing signature, and passes only via the zero-exchanges branch.
          family: test-does-not-pin-the-fix
          round: 14
        - id: BR-74
          severity: Minor
          title: a stranded two-line fragment remains at the issue's :647-648 after revision 11 was moved
          detail: |-
            This is the 3rd finding in family `markdown-block-not-separated`. Do not just delete these two lines —
            the rule from BR-67 still applies and was not: a `## Revisions` entry is appended to `## Revisions`,
            never left in the section it revises, and its number is unique across the issue. Entries 9-11 are still
            under `## Log`; 1/2/3 are used twice; and the move left
            "      (placement is the cursor, not the exchange end) and the 3a/3b split is gone" dangling after revision 11's body.
          family: markdown-block-not-separated
          round: 14
      boundary: M3
      blocked: true
    - "n": 15
      timestamp: "2026-09-07T18:56:41-07:00"
      agent: claude
      dispose:
        - id: BR-58
          disposition: addressed
          note: make_handle anchor + fixtures on both sides of the delta axis; reverting the anchor turns 2 integration tests red.
          round: 15
        - id: BR-59
          disposition: addressed
          note: Plan Core concepts + Task 3 carry corrections, issue Core concepts rewritten, Deviations entry 0 records the removal, ledger rows struck.
          round: 15
        - id: BR-60
          disposition: addressed
          note: Task 7 steps removed with a NOT-DELIVERED note; three ledger rows struck; bracket unified via chat_gather_opts with a no-rebuild test; scope difference stated as deliberate in README, atlas and module header.
          round: 15
        - id: BR-61
          disposition: addressed
          note: gf bullet restored; keybinding_agreement_spec now derives README-key to registry agreement and pins the headline chords in the reverse direction.
          round: 15
        - id: BR-66
          disposition: not-addressed
          note: Predicate still duplicated; the new rationale "would cost a call per line" is contradicted by kinds[] at chat_parser.lua:557, which already holds classify's answer for every line.
          round: 15
        - id: BR-67
          disposition: addressed
          note: Revisions consolidated under one heading, numbering unique 1-17 — but the renumbering broke five cross-references; raised separately.
          round: 15
        - id: BR-68
          disposition: addressed
          note: branch_ref.ref_block owns the margin for both insert paths; reverting it turns the prose-both-sides test red.
          round: 15
        - id: BR-69
          disposition: addressed
          note: refuse_while_pending wraps the n/i/v dispatch table; reverting v turns the every-mode test red.
          round: 15
        - id: BR-70
          disposition: addressed
          note: atlas/chat/drill_in.md now names chat_gather_opts as the owner with both consumers.
          round: 15
        - id: BR-71
          disposition: not-addressed
          note: The redundant drill_in.parse was removed, but M.parse_chat still runs unconditionally at init.lua:2280 before the gather, and the adjacent comment claims the gather is asked first.
          round: 15
        - id: BR-72
          disposition: not-addressed
          note: apply_text_edits and nvim_buf_set_lines at init.lua:2337-2352 remain unguarded between the pcall'd create and commit_reference.
          round: 15
        - id: BR-73
          disposition: not-addressed
          note: Both tests unchanged — branch_submit_spec.lua:126 still passes {} for a boolean, and :131-136 still names a content check plan_submission never performs.
          round: 15
        - id: BR-74
          disposition: not-addressed
          note: The two-line fragment is still stranded, now at issue lines 799-800 after revision 15's body.
          round: 15
      findings:
        - id: BR-75
          severity: Critical
          title: "a mid-component \U0001F33F:/\U0001F512: annotation is inside the span a resubmit deletes, so <M-CR> destroys the reference the chord just inserted"
          detail: "This is the 2nd finding in family `merged-path-loses-original-effect`. Do not\nre-fix the trailing case — the rule is: when a latch is replaced by per-line\nhandling, enumerate every effect the latch provided and restore each across\nits whole axis, not at the one position a fixture happens to test. The\nline_before_local latch provided content exclusion (deliberately dropped) AND\ntruncation of the component's line_end at the marker; only the trailing half\nof the second was restored by the annotation-aware trim at\nchat_parser.lua:335-352.\nMeasured against a base worktree, same transcript: answer.line_end is 10 at\nd5ba3eb and 16 at HEAD for a \U0001F33F: at line 12. chat_respond.lua:1436 calls\ndelete_answer(buf, question.line_end, answer.line_end - 1) →\nnvim_buf_set_lines(buf, 6, 16) → deletes 1-indexed 7..16 including the\nreference. Driving the real chord (_branch_inserters(buf,false,true).n() at\nline 10 of an answer with text after it) lands the \U0001F33F: at 12, inside 7..16 —\nso the next resubmit of that exchange orphans the child chat on disk (BR-19)\nand silently deletes any mid-answer \U0001F512: private note in the same range.\natlas/chat/inline_branch_links.md:38-43 asserts the opposite. Fix: make the\nresubmit deletion annotation-preserving, pinned by a test that resubmits an\nexchange carrying both a mid-answer reference and a mid-answer note."
          family: merged-path-loses-original-effect
          round: 15
        - id: BR-76
          severity: Important
          title: the BR-67 revision renumbering invalidated five cross-references, which now point at unrelated decisions
          detail: |-
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
          family: reference-written-in-unresolvable-form
          round: 15
        - id: BR-77
          severity: Minor
          title: two new functions were spliced into the middle of an adjacent function's doc-comment block
          detail: |-
            This is the 4th finding in family `markdown-block-not-separated`. Do not fix
            the two sites — the rule generalises past markdown: a block is inserted
            BETWEEN complete blocks, never into the middle of one.
            helper.lua:117 puts flatten_lines between "---@return string # returns unique
            uuid" and _H.uuid, so uuid loses its annotation and flatten_lines gains a
            bogus second @return. drill_in.lua:346 puts chat_gather_opts between
            chat_boundaries' description plus @param cfg and its @return string[], so
            chat_boundaries is left with only a return type and chat_gather_opts inherits
            prose about the anchor scan that describes its neighbour.
          family: markdown-block-not-separated
          round: 15
        - id: BR-78
          severity: Minor
          title: helper.flatten_lines shipped as a new exported pure entity with no Core-concepts row
          detail: |-
            This is the 2nd finding in family `artifact-missing-from-its-index`. The rule
            covering both: a new exported entity is added to the Core-concepts table that
            enumerates its kind, in the same commit that introduces it.
            flatten_lines is new, exported, unit-tested and guarded by an arch spec, but
            appears in neither the issue's nor the plan's Core concepts. The plan's table
            also omits ref_block and chat_gather_opts, which the issue's table does carry
            — so the two tables disagree about what M3 delivered.
          family: artifact-missing-from-its-index
          round: 15
      boundary: M3
      blocked: true
    - "n": 16
      timestamp: "2026-09-07T19:21:28-07:00"
      agent: claude
      dispose:
        - id: BR-66
          disposition: addressed
          note: inline re-match retired; single owner exists, though outside highlight_structure — see I1.
          round: 16
        - id: BR-71
          disposition: not-addressed
          note: init.lua:2281 still parses before the gather at :2289; the comment claims the reverse ordering.
          round: 16
        - id: BR-72
          disposition: not-addressed
          note: init.lua:2340 and :2351 remain unguarded after the pcall'd create at :2317; insert_inline is a second site.
          round: 16
        - id: BR-73
          disposition: not-addressed
          note: branch_submit_spec.lua:125 still passes `{}` for a boolean; :131 still names a content check plan_submission never makes.
          round: 16
        - id: BR-74
          disposition: not-addressed
          note: numbering is now unique 4-17 and all under Revisions, but the two-line fragment at issue :807-808 is still dangling.
          round: 16
        - id: BR-75
          disposition: addressed
          note: 'verified by reversion — three assertions in annotation_lines_spec go red without the fix. Class incomplete: see C1.'
          round: 16
        - id: BR-76
          disposition: addressed
          note: citations now use dated headings and the section states the rule; no ordinal citations remain in issue or plan.
          round: 16
        - id: BR-77
          disposition: not-addressed
          note: helper.lua:116 and drill_in.lua:345 unchanged; this round added a third site at buffer_edit.lua:96.
          round: 16
        - id: BR-78
          disposition: addressed
          note: plan table synced with (as built) rows and the two records labelled; delete_answer is still absent from the issue's table.
          round: 16
      findings:
        - id: BR-79
          severity: Critical
          title: "an inline [\U0001F33F:…](child.md) inside an answer is still destroyed by a resubmit, orphaning the child"
          detail: "This is the 3rd finding in family `merged-path-loses-original-effect`. Do not fix\nthe inline case as an instance — the rule is: the survivor set of a resubmit is\nevery user-authored pointer to a durable artifact inside the deleted span, derived\nfrom the parser's own branch/annotation extraction rather than from a line-prefix\ntest. `is_annotation` answers \"does this line START with a prefix\", which is\nstrictly narrower than \"does this line carry a reference\".\nMeasured end-to-end: driving the real visual chord\n(_branch_inserters(buf,false,true).v()) over text inside an answer in a chat buffer\nproduces `the answer talks about m[\U0001F33F:onads ](2026-09-07.19-18-20.725.md)here`,\ncreates the child on disk and writes the parent; the parser reports branches=1.\nbuffer_edit.delete_answer(buf, question.line_end, answer.line_end - 1) — the exact\ncall at chat_respond.lua:1436 — then leaves the buffer at `\U0001F4AC: first question` with\nthe link gone and the child unreachable. Identical consequence to BR-75, one\nposition over on the same axis, on a path README.md and\natlas/chat/inline_branch_links.md both document first.\nFix: extract a pure `annotation.survivors(lines, cfg)` that keeps annotation-prefixed\nlines AND lines carrying an inline branch link (reusing\nchat_parser.extract_inline_branch_links, not a second matcher); pin with a resubmit\ntest carrying a full-line \U0001F33F:, a full-line \U0001F512: and an inline [\U0001F33F:…](f) at once."
          family: merged-path-loses-original-effect
          round: 16
        - id: BR-80
          severity: Important
          title: annotation.is_annotation fabricates the shipped prefixes for a missing live config, the shape is_partition exists to forbid
          detail: |-
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
          family: silent-fallback-to-shipped-default
          round: 16
        - id: BR-81
          severity: Minor
          title: two live comments still assert the line_before_local latch this window deleted
          detail: "This is the 6th finding in family `stale-comment-after-move`. Do not fix the two\nsites — the rule is: a commit that removes a mechanism greps for its name and\nupdates or deletes every prose reference in the same commit.\nbranch_submit.lua:26-31 (\"The cost is measured and real: \U0001F33F: sets the parser's\nline_before_local ... so answer text AFTER a mid-answer reference is excluded from\nthe LLM context and the exchange model truncates that exchange\") and\nbranch_child_spec.lua:408-412 both state a behaviour b9fc6c8 removed INSIDE this\nwindow, and which README.md and atlas/chat/parsing.md now describe the opposite way.\n`grep -rn line_before_local lua/ tests/` returns these two live claims plus four\ncorrectly-historical ones."
          family: stale-comment-after-move
          round: 16
        - id: BR-82
          severity: Minor
          title: annotation.lua is in no traceability entry, and its spec is filed under the atlas doc it does not verify
          detail: |-
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
          family: artifact-missing-from-its-index
          round: 16
        - id: BR-83
          severity: Minor
          title: the M3 plan ticks its own milestone-close, and two steps still describe superseded decisions
          detail: "This is the 3rd finding in family `plan-not-revised-after-decision-change`. Do not\nfix the three rows — the rule is: when a decision is superseded, the same edit\nsweeps every step, risk and checkbox that depends on it; and a checkbox is ticked by\nthe action, never in advance.\nworkshop/plans/000214-branch-submit-m3-plan.md:330 ticks `sdlc milestone-close\n--issue 214 --milestone M3` although this review IS that gate and the issue's `## Log`\ncarries no M3 entry. :322 ticks \"including the measured reason the ref follows \U0001F4DD:\"\nfor docs that now say placement is the cursor. The \"Open risks\" block still names\ncase 2b's \"last exchange\", which the narrowing removed."
          family: plan-not-revised-after-decision-change
          round: 16
        - id: BR-84
          severity: Minor
          title: delete_answer's doc claims survivors do not drift to the end; in the composed resubmit they do
          detail: |-
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
          family: docs-assert-unverified-behavior
          round: 16
        - id: BR-85
          severity: Minor
          title: workshop/000214-smoke.md sits at the workshop root, which names no datatype
          detail: |-
            This is the 3rd finding in family `scratch-artifact-swept-into-commit`. Do not just
            move the file — the rule is: a workshop artifact lives in the subdirectory its
            datatype names (issues/, plans/, parley/, pensive/, projects/, targets/, vision/);
            nothing lands at workshop/ root. This is guard-enforceable.
            NOTE: this arrived in ddb5614, which is OUTSIDE the pinned review window
            (d5ba3eb..87ecc53). The working tree is two commits ahead of the pinned head —
            3d8ab7b and ddb5614 have not been reviewed by any gate. Re-pin or review them
            before recording the M3 verdict.
          family: scratch-artifact-swept-into-commit
          round: 16
      boundary: M3
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

## Round 11 — 2026-09-07T16:15:14-07:00 (claude) — passed

### Disposed

- BR-47 — addressed — Verified by reversion — round 9's buffer-local shape reds both halves (spell's map destroyed; mode confined to one buffer); dropping the restore reds 3 more.
- BR-48 — addressed — Verified by reversion — removing the two knobs from config.lua reds the new derived assertion. See the Minor on its substring predicate.
- BR-49 — not-addressed — Headline fixed and pinned; two of the four shapes the finding enumerated still coerce silently — see N3.
- BR-50 — addressed — All three parts verified — global plant reds 3, feature_gated has both guards, traceability guard reds on a real branch when a spec is unrouted.
- BR-51 — addressed — Resolved by reverting the mechanism, so init.lua/spell.lua read true again — but the atlas and lessons.md were not swept back (N1).
- BR-52 — not-addressed — The three blocks at keybinding_agreement_spec.lua:141-146, :163-168, :334-338 are untouched this round.

### Raised

- **BR-53** [Important] `stale-comment-after-move` atlas and lessons.md still teach the interview-<CR> design round 10 reversed
  atlas/ui/keybindings.md:130 states "Interview's <CR> is buffer-local … del must never be aimed
  at a global map"; the shipped map is global (interview.lua:112) and round 10's own commit says
  del cannot distinguish ownership at ANY scope. workshop/lessons.md:1435 carries the same
  reversed claim as a RULE every agent reads at session start, so following it re-creates BR-47.
  4th in family. Rule — when a round reverses a prior round's decision, the artifacts that
  recorded it are part of the reversal's diff and are mechanically enumerable via
  `git show --stat` of the reversed commit: a84108a touched atlas/ui/keybindings.md,
  workshop/lessons.md, interview.lua and the issue; 5bc1a41 touched only the last two.
  Enumeration: the atlas paragraph, the lessons rule, and the missing ## Revisions / ## Log entry.
- **BR-54** [Important] `no-seam-for-ordering` the new interview tests drive setup_keymap/remove_keymap, never enter/exit — and enter/exit raises
  keybinding_agreement_spec.lua:420-508 exercises the two internal steps. Driving the real
  transition instead raises, measured through the production BufEnter path: interview.enter()
  then opening any chat file gives "Cannot deepcopy object of type userdata" at init.lua:1347
  (refresh_state) from init.lua:2310 (prep_chat), because start_timer stores a vim.loop handle in
  _state.interview_timer (interview.lua:193). Pre-existing and outside the window, so not a
  blocker on its own; it matters because round 10's rationale is "the map lives at the same scope
  as the session state it serves" and that state's lifecycle cannot currently run, and because the
  tests added this round are the ones that would have caught it. 4th in family. Rule — a lifecycle
  fix must be pinned through the transition the user triggers, not the internal step the fix
  edited. Enumeration: convert the six tests to enter()/exit() (both work headless), and keep the
  timer handle out of the deepcopied state.
- **BR-55** [Minor] `derive-before-validate` _explicit_shortcuts is computed from raw opts before setup() strips malformed values
  init.lua:546 walks the raw opts; the malformed-shortcut strip runs at :636. A knob whose value is
  later stripped stays marked explicit, so the master switch lets it through and it falls back to
  default_key. Measured — default_keymaps = false plus chat_shortcut_respond = { shortcut = 5 }
  binds <C-g><C-g>, a default key on a config that asked for none. Build the explicit set from the
  normalised config, or clear the entry when stripping.
- **BR-56** [Minor] `test-does-not-pin-the-fix` the BR-48 derived guard uses an unanchored substring, so 8 of 15 dotted knobs cannot fail it
  keybinding_agreement_spec.lua:526 asserts shipped_src:find(leaf, 1, true). Leaf "delete" occurs
  11 times in config.lua, "move" 7, "next_recency" 3 — so deleting note_finder_mappings.delete,
  chat_finder_mappings.move and six siblings leaves the test green. 5th in family. Rule — a derived
  assertion must be member-discriminating: verify it by deleting one member at a time for EVERY
  member, not for the two the finding happened to name. Anchor the match to an assignment.
- **BR-57** [Minor] `markdown-block-not-separated` README's "Every knob is named in config.lua" is swallowed into the preceding bullet
  README.md:277 follows a list item with no blank line, so GFM lazy continuation renders this
  section-level claim as part of the `u`/`<C-r>` bullet.

## Round 12 — 2026-09-07T16:42:25-07:00 (claude) — passed

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 13 — 2026-09-07T18:11:18-07:00 (claude) — BLOCKED

### Raised

- **BR-58** [Critical] `stale-position-across-buffer-edit` the 🌿: reference position is computed before the marker strip and used after it
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
- **BR-59** [Critical] `plan-not-revised-after-decision-change` the plan's and issue's Core concepts tables describe a plan_submission the code does not implement
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
- **BR-60** [Critical] `docs-assert-unverified-behavior` Task 7's <M-CR> agreement check is checked off but absent, and the equivalence it guarded is already false
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
- **BR-61** [Important] `readme-missing-for-changed-surface` the gf smart go-to-file bullet was deleted from README as collateral of the <M-i> rewrite
  This is the 3rd finding in family `readme-missing-for-changed-surface`. Do not
  just restore the line — state the rule: README's binding list and the registry's
  resolved default keys must agree, and that agreement should be derived, not
  reviewed. M2 already built the machinery (keybinding_agreement_spec.lua, key_for)
  and already caught three README-documented commands that were never implemented;
  extend the same derivation to bindings so a bullet cannot vanish silently.
  `git show d5ba3eb:README.md` line 179 documents `gf`; it is absent at HEAD and
  `gf` is still shipped.
- **BR-62** [Important] `test-harness-assumption` the new unit spec calls parley.setup() per test, and make test is red from a clean environment
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
- **BR-63** [Important] `partial-effect-not-committed` create_child_chat is unguarded after the parent has already been stripped and the reference inserted
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
- **BR-64** [Important] `breaking-change-without-upgrade-note` 🔒: content previously withheld from the LLM is now submitted, with no upgrade note
  atlas/chat/format.md documented 🔒: as a local SECTION excluded from LLM context;
  chat_parser.lua:606-613 makes it one line. A user whose transcripts used the
  documented semantics silently begins submitting every line after the first noted
  one on their next request. The measurement cited (0 of 16 chats in the operator's
  corpus) bounds the operator's exposure, not a published plugin's users. The atlas
  records the new behaviour; README has no upgrade or breaking-change section and
  never documented the prefix, so there is nowhere a user would see this
  (ARCH-SECURE at-review).
- **BR-65** [Minor] `dead-value-in-new-code` ready_marker_lines computes a line number per marker that plan_submission never reads
  This is the 2nd finding in family `dead-value-in-new-code`. Do not just delete
  the field — the rule is: a value computed to satisfy a signature must be read by
  that signature's implementation, or the parameter goes away; a dead field in a
  "pure decision" module is what makes the module look like it decides more than it
  does. init.lua:2266-2278 counts newlines per ready marker to build { line = N };
  branch_submit.lua:87-101 only tests #markers > 0. The same pass also runs
  drill_in.parse over the whole buffer a second time — gather_edit_plan at :2329
  parses again.
- **BR-66** [Minor] `duplicate-helper-not-retired` annotation_line re-implements the classifier's predicate while its comment claims it reuses it
  This is the 7th finding in family `duplicate-helper-not-retired`. Earlier rounds
  fixed instances. Do not fix this instance — the rule is: a line-kind predicate
  lives in highlight_structure beside the patterns it reads, and callers ask it
  rather than re-matching pattern fields; highlight_structure.is_partition
  (:180-198) is the precedent for exactly this. chat_parser.lua:335-342 defines
  annotation_line inline (rebuilt per finalize_component call) matching
  local_pattern/branch_pattern directly, under a comment asserting it reuses
  highlight_structure.classify. Add is_annotation(line, patterns) there and call it.
- **BR-67** [Minor] `markdown-block-not-separated` revision 11 was written into the middle of the M3 Plan bullet instead of into ## Revisions
  This is the 2nd finding in family `markdown-block-not-separated`. Do not just move
  this block — the rule is: a `## Revisions` entry is appended to `## Revisions`,
  never inlined into the artifact section it revises, and its number is unique
  across the issue.
  workshop/issues/000214-curate-default-keybindings.md:507 puts a `###` heading and
  its body between "Rows 2a/2b collapse" and "(placement is the cursor, not the
  exchange end)", severing the bullet and nesting a heading inside `## Plan`.
  `## Revisions` is at :764, and the numbered entries 1-11 are currently split
  across `## Plan`, `## Log` and `## Revisions` with 1/2/3 used twice.

## Round 14 — 2026-09-07T18:32:20-07:00 (claude) — BLOCKED

### Disposed

- BR-58 — not-addressed — make_handle takes a 0-indexed row but is passed the 1-indexed cursor line, so the
anchor sits on the whitespace gap that drill_in.lua:457-458 swallows into its `]`
edit; with left gravity the mark collapses and the ref lands ABOVE the cursor line.
Reproduced: standalone marker directly below the cursor, and inline-above + standalone-below.
Every new fixture puts the marker above the cursor, so the suite samples one side of the axis.
- BR-59 — not-addressed — Core-concepts tables corrected in both plan and issue and the ledger rows struck, but
the plan's Task 3 steps are still `- [x]` over six assertions absent from the tree, and
`## Deviations` still records no entry for the removal — two of the four artifacts the rule named.
- BR-60 — not-addressed — Task 7's body now says NOT DELIVERED and the ledger row is struck, but `## Deviations`
item 2 still states verbatim that the check runs plan_submission's exchange resolution
against find_exchange_at_line over three transcripts, verified by three red tests. No such test exists.
- BR-61 — not-addressed — The `gf` bullet is restored, but the derivation the finding asked for was not built —
no test relates README's binding bullets to the registry's resolved default keys, so the
next bullet can still vanish silently. Instance fixed, class open.
- BR-62 — addressed — setup() dropped from the new spec; two clean-environment `make test` runs green (200 files).
The ensure_dir_exists half is unnecessary — measured that vim.fn.mkdir(existing, "p") returns
1 without error on nvim 0.11.7, and every mkdir in lua/ passes "p".
- BR-63 — addressed — Create now precedes every buffer mutation and is pcall'd; branch_child_spec.lua:820-838
simulates the failure and asserts the markers survive. See Minor M2 for the unswept half
(the effects after the create are now the unguarded ones).
- BR-64 — addressed — README now carries an explicit upgrade note under "Two config contracts changed"; the atlas
records the single-line semantics in both format.md and parsing.md.
- BR-65 — addressed — ready_marker_lines is gone (grep: zero hits) and the second drill_in.parse pass with it;
the gather is now asked first and is the authority. See Minor M1 for the parse_chat that remains unconditional.
- BR-66 — not-addressed — The false comment is fixed and the closure hoisted out of finalize_component, but the
predicate still re-matches local_pattern/branch_pattern in chat_parser instead of living in
highlight_structure as is_annotation. A reasoned counter-argument is given in the comment; the stated rule is not followed.
- BR-67 — not-addressed — The block no longer severs the Plan bullet, but the rule was not applied: entries 9-11 still
live under `## Log` rather than `## Revisions`, numbers 1/2/3 remain duplicated across the two
sections, and the move stranded a two-line fragment at issue :647-648.

### Raised

- **BR-68** [Important] `docs-assert-unverified-behavior` the "one blank line each side" margin is asserted in three artifacts and held by neither insert path
  init.lua:2343-2345 inserts { "", ref } — one blank BEFORE only — under a comment claiming
  "one blank line each side"; insert_plain at :2387-2390 inserts the bare line with no blank on
  either side. The plan says `add_block(k, "branch_ref", 1, 1)` and no such block kind exists in
  exchange_model.lua. Measured: cursor line followed immediately by non-blank prose leaves the ref
  abutting the next line; the two-marker case leaves two blanks before it. The existing assertions
  (branch_child_spec.lua:397, 419-420) pass only because those fixtures happen to have a blank in the
  right place. Rule: an invariant stated in a comment or plan is pinned by a fixture that would violate
  it if the code were wrong — here, non-blank text on BOTH sides — and one key gets one spacing rule in one helper.
- **BR-69** [Important] `docs-assert-unverified-behavior` the pending-response refusal covers n and i but not v, while README and the atlas state it for the whole chord
  init.lua:2288 guards insert_planned, reachable only from insert_plain (n/i). insert_inline at
  :2425-2452 runs create_child_if_owned and commit_reference with no check. README.md's closing
  paragraph ("It declines while a response is still streaming into that chat") and
  atlas/chat/inline_branch_links.md:60-62 ("Refusals. The chord declines...") both assert it for all
  three cases. init.lua:2216-2219 already states the governing rule for this file: the enumeration is
  the dispatch table n/i/v, not the path in front of you. Lift the guard above the dispatch table, or narrow both documents.
- **BR-70** [Important] `stale-comment-after-move` atlas/chat/drill_in.md still names chat_respond as the owner of the gather options
  :130-137 read "chat_respond assembles them from config" and "opts.bracket (set by chat_respond from
  config.mark_reference_span)". The owner is now drill_in.chat_gather_opts with two consumers. The file
  is named in the plan's Task 8 file list and is absent from the diff — new surface with no update to its
  home atlas page (AGENTS.md section 8).
- **BR-71** [Minor] `derive-before-validate` a full parse_chat runs on every M-i press to answer only "are there zero exchanges"
  init.lua:2296 parses the whole buffer (M.parse_chat is uncached, init.lua:3709) before the
  has_markers check that decides whether a plan is possible at all; on the common no-marker path the
  result is discarded. Ask the gather first, then parse only when a plan can exist. ARCH-CONSTRAINTS:
  this is an interactive keypress path now doing two full-buffer passes with no declared envelope.
- **BR-72** [Minor] `partial-effect-not-committed` BR-63 moved the point of no return, and the effects after it are now the unguarded ones
  This is the 5th finding in family `partial-effect-not-committed`. Earlier rounds fixed instances.
  Do not guard the one call — the rule BR-63 stated still has an unswept half: within a single keypress
  transition, every effect after the point of no return is guarded the same way and a failure states what
  the buffer is left holding. create_child_if_owned is now pcall'd and first (init.lua:2329); the
  apply_text_edits and nvim_buf_set_lines at :2337-2345 that follow it are not, so a raise there leaves a
  child on disk with no reference — BR-19's orphan by the reverse route. Low probability, since the edits are drill_in's own.
- **BR-73** [Minor] `test-does-not-pin-the-fix` two plan_submission decline tests are green for reasons unrelated to their names
  This is the 6th finding in family `test-does-not-pin-the-fix`. Do not fix these two — the rule is:
  a test's name states the branch it takes, and the assertion fails if that branch is removed.
  branch_submit_spec.lua:135-140 "a question with no text has nothing to submit" passes has_markers = false
  and plan_submission never inspects question.content, so it exercises the marker branch and would stay
  green if the content check it names were added and then broken. :129 passes `{}` (truthy) for a boolean
  parameter, a leftover from the pre-narrowing signature, and passes only via the zero-exchanges branch.
- **BR-74** [Minor] `markdown-block-not-separated` a stranded two-line fragment remains at the issue's :647-648 after revision 11 was moved
  This is the 3rd finding in family `markdown-block-not-separated`. Do not just delete these two lines —
  the rule from BR-67 still applies and was not: a `## Revisions` entry is appended to `## Revisions`,
  never left in the section it revises, and its number is unique across the issue. Entries 9-11 are still
  under `## Log`; 1/2/3 are used twice; and the move left
  "      (placement is the cursor, not the exchange end) and the 3a/3b split is gone" dangling after revision 11's body.

## Round 15 — 2026-09-07T18:56:41-07:00 (claude) — BLOCKED

### Disposed

- BR-58 — addressed — make_handle anchor + fixtures on both sides of the delta axis; reverting the anchor turns 2 integration tests red.
- BR-59 — addressed — Plan Core concepts + Task 3 carry corrections, issue Core concepts rewritten, Deviations entry 0 records the removal, ledger rows struck.
- BR-60 — addressed — Task 7 steps removed with a NOT-DELIVERED note; three ledger rows struck; bracket unified via chat_gather_opts with a no-rebuild test; scope difference stated as deliberate in README, atlas and module header.
- BR-61 — addressed — gf bullet restored; keybinding_agreement_spec now derives README-key to registry agreement and pins the headline chords in the reverse direction.
- BR-66 — not-addressed — Predicate still duplicated; the new rationale "would cost a call per line" is contradicted by kinds[] at chat_parser.lua:557, which already holds classify's answer for every line.
- BR-67 — addressed — Revisions consolidated under one heading, numbering unique 1-17 — but the renumbering broke five cross-references; raised separately.
- BR-68 — addressed — branch_ref.ref_block owns the margin for both insert paths; reverting it turns the prose-both-sides test red.
- BR-69 — addressed — refuse_while_pending wraps the n/i/v dispatch table; reverting v turns the every-mode test red.
- BR-70 — addressed — atlas/chat/drill_in.md now names chat_gather_opts as the owner with both consumers.
- BR-71 — not-addressed — The redundant drill_in.parse was removed, but M.parse_chat still runs unconditionally at init.lua:2280 before the gather, and the adjacent comment claims the gather is asked first.
- BR-72 — not-addressed — apply_text_edits and nvim_buf_set_lines at init.lua:2337-2352 remain unguarded between the pcall'd create and commit_reference.
- BR-73 — not-addressed — Both tests unchanged — branch_submit_spec.lua:126 still passes {} for a boolean, and :131-136 still names a content check plan_submission never performs.
- BR-74 — not-addressed — The two-line fragment is still stranded, now at issue lines 799-800 after revision 15's body.

### Raised

- **BR-75** [Critical] `merged-path-loses-original-effect` a mid-component 🌿:/🔒: annotation is inside the span a resubmit deletes, so <M-CR> destroys the reference the chord just inserted
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
- **BR-76** [Important] `reference-written-in-unresolvable-form` the BR-67 revision renumbering invalidated five cross-references, which now point at unrelated decisions
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
- **BR-77** [Minor] `markdown-block-not-separated` two new functions were spliced into the middle of an adjacent function's doc-comment block
  This is the 4th finding in family `markdown-block-not-separated`. Do not fix
  the two sites — the rule generalises past markdown: a block is inserted
  BETWEEN complete blocks, never into the middle of one.
  helper.lua:117 puts flatten_lines between "---@return string # returns unique
  uuid" and _H.uuid, so uuid loses its annotation and flatten_lines gains a
  bogus second @return. drill_in.lua:346 puts chat_gather_opts between
  chat_boundaries' description plus @param cfg and its @return string[], so
  chat_boundaries is left with only a return type and chat_gather_opts inherits
  prose about the anchor scan that describes its neighbour.
- **BR-78** [Minor] `artifact-missing-from-its-index` helper.flatten_lines shipped as a new exported pure entity with no Core-concepts row
  This is the 2nd finding in family `artifact-missing-from-its-index`. The rule
  covering both: a new exported entity is added to the Core-concepts table that
  enumerates its kind, in the same commit that introduces it.
  flatten_lines is new, exported, unit-tested and guarded by an arch spec, but
  appears in neither the issue's nor the plan's Core concepts. The plan's table
  also omits ref_block and chat_gather_opts, which the issue's table does carry
  — so the two tables disagree about what M3 delivered.

## Round 16 — 2026-09-07T19:21:28-07:00 (claude) — BLOCKED

### Disposed

- BR-66 — addressed — inline re-match retired; single owner exists, though outside highlight_structure — see I1.
- BR-71 — not-addressed — init.lua:2281 still parses before the gather at :2289; the comment claims the reverse ordering.
- BR-72 — not-addressed — init.lua:2340 and :2351 remain unguarded after the pcall'd create at :2317; insert_inline is a second site.
- BR-73 — not-addressed — branch_submit_spec.lua:125 still passes `{}` for a boolean; :131 still names a content check plan_submission never makes.
- BR-74 — not-addressed — numbering is now unique 4-17 and all under Revisions, but the two-line fragment at issue :807-808 is still dangling.
- BR-75 — addressed — verified by reversion — three assertions in annotation_lines_spec go red without the fix. Class incomplete: see C1.
- BR-76 — addressed — citations now use dated headings and the section states the rule; no ordinal citations remain in issue or plan.
- BR-77 — not-addressed — helper.lua:116 and drill_in.lua:345 unchanged; this round added a third site at buffer_edit.lua:96.
- BR-78 — addressed — plan table synced with (as built) rows and the two records labelled; delete_answer is still absent from the issue's table.

### Raised

- **BR-79** [Critical] `merged-path-loses-original-effect` an inline [🌿:…](child.md) inside an answer is still destroyed by a resubmit, orphaning the child
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
- **BR-80** [Important] `silent-fallback-to-shipped-default` annotation.is_annotation fabricates the shipped prefixes for a missing live config, the shape is_partition exists to forbid
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
- **BR-81** [Minor] `stale-comment-after-move` two live comments still assert the line_before_local latch this window deleted
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
- **BR-82** [Minor] `artifact-missing-from-its-index` annotation.lua is in no traceability entry, and its spec is filed under the atlas doc it does not verify
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
- **BR-83** [Minor] `plan-not-revised-after-decision-change` the M3 plan ticks its own milestone-close, and two steps still describe superseded decisions
  This is the 3rd finding in family `plan-not-revised-after-decision-change`. Do not
  fix the three rows — the rule is: when a decision is superseded, the same edit
  sweeps every step, risk and checkbox that depends on it; and a checkbox is ticked by
  the action, never in advance.
  workshop/plans/000214-branch-submit-m3-plan.md:330 ticks `sdlc milestone-close
  --issue 214 --milestone M3` although this review IS that gate and the issue's `## Log`
  carries no M3 entry. :322 ticks "including the measured reason the ref follows 📝:"
  for docs that now say placement is the cursor. The "Open risks" block still names
  case 2b's "last exchange", which the narrowing removed.
- **BR-84** [Minor] `docs-assert-unverified-behavior` delete_answer's doc claims survivors do not drift to the end; in the composed resubmit they do
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
- **BR-85** [Minor] `scratch-artifact-swept-into-commit` workshop/000214-smoke.md sits at the workshop root, which names no datatype
  This is the 3rd finding in family `scratch-artifact-swept-into-commit`. Do not just
  move the file — the rule is: a workshop artifact lives in the subdirectory its
  datatype names (issues/, plans/, parley/, pensive/, projects/, targets/, vision/);
  nothing lands at workshop/ root. This is guard-enforceable.
  NOTE: this arrived in ddb5614, which is OUTSIDE the pinned review window
  (d5ba3eb..87ecc53). The working tree is two commits ahead of the pinned head —
  3d8ab7b and ddb5614 have not been reviewed by any gate. Re-pin or review them
  before recording the M3 verdict.

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
- **BR-49** [Important] `illegal-state-representable-in-signature` the malformed-shortcut warning fires at every resolution instead of parsing once at the boundary
- **BR-52** [Minor] `duplicate-helper-not-retired` three near-identical known-set/diff blocks in the agreement spec
- **BR-53** [Important] `stale-comment-after-move` atlas and lessons.md still teach the interview-<CR> design round 10 reversed
- **BR-54** [Important] `no-seam-for-ordering` the new interview tests drive setup_keymap/remove_keymap, never enter/exit — and enter/exit raises
- **BR-55** [Minor] `derive-before-validate` _explicit_shortcuts is computed from raw opts before setup() strips malformed values
- **BR-56** [Minor] `test-does-not-pin-the-fix` the BR-48 derived guard uses an unanchored substring, so 8 of 15 dotted knobs cannot fail it
- **BR-57** [Minor] `markdown-block-not-separated` README's "Every knob is named in config.lua" is swallowed into the preceding bullet
- **BR-71** [Minor] `derive-before-validate` a full parse_chat runs on every M-i press to answer only "are there zero exchanges"
- **BR-72** [Minor] `partial-effect-not-committed` BR-63 moved the point of no return, and the effects after it are now the unguarded ones
- **BR-73** [Minor] `test-does-not-pin-the-fix` two plan_submission decline tests are green for reasons unrelated to their names
- **BR-74** [Minor] `markdown-block-not-separated` a stranded two-line fragment remains at the issue's :647-648 after revision 11 was moved
- **BR-77** [Minor] `markdown-block-not-separated` two new functions were spliced into the middle of an adjacent function's doc-comment block
- **BR-79** [Critical] `merged-path-loses-original-effect` an inline [🌿:…](child.md) inside an answer is still destroyed by a resubmit, orphaning the child
- **BR-80** [Important] `silent-fallback-to-shipped-default` annotation.is_annotation fabricates the shipped prefixes for a missing live config, the shape is_partition exists to forbid
- **BR-81** [Minor] `stale-comment-after-move` two live comments still assert the line_before_local latch this window deleted
- **BR-82** [Minor] `artifact-missing-from-its-index` annotation.lua is in no traceability entry, and its spec is filed under the atlas doc it does not verify
- **BR-83** [Minor] `plan-not-revised-after-decision-change` the M3 plan ticks its own milestone-close, and two steps still describe superseded decisions
- **BR-84** [Minor] `docs-assert-unverified-behavior` delete_answer's doc claims survivors do not drift to the end; in the composed resubmit they do
- **BR-85** [Minor] `scratch-artifact-swept-into-commit` workshop/000214-smoke.md sits at the workshop root, which names no datatype
