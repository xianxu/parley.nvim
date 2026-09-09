---
gate: boundary-review
issue: 225
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-08T19:16:06-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: Row 4 bundles "split-aware edit" with the Explore arm, but markdown already has it via open_buf
          detail: |-
            3rd in family, so the ask is the RULE: an "X exists only in path A" claim must cite the
            ABSENCE in path B, not the presence in A. Measured prevalence 3. Here the cited range
            (init.lua:4463-4492) backs the directory Explore arm only; the chat chain's split-aware
            edit is at init.lua:4574-4597 and duplicates M.open_buf's logic (init.lua:2963-2984),
            which markdown already reaches. Keeping it behind is_chat carries the duplication through
            the extraction (ARCH-DRY); collapsing it onto open_buf also adds file-tracking
            (init.lua:2945-2946) and existing-window reuse (init.lua:2948-2958) to the chat path.
            (carried from plan-quality PQ-9, deferred to the boundary review)
          family: unbacked-existing-behavior-claim
          round: 1
        - id: BR-2
          severity: Minor
          title: The M-o consumer list is recalled, not grep-derived; omits keybinding_registry.lua:750 and three keybinding_agreement_spec assertions
          detail: |-
            2nd in family, so the RULE: a plan moving a key or identifier derives its update list from
            a grep of the literal and dispositions every hit, including each test asserting the old
            value as "will fail" / "passes for the wrong reason" / "unaffected". Measured: 13 hits in
            7 files, plan names 2 files. keybinding_registry.lua:750 is review_menu's functional
            default_key. keybinding_agreement_spec.lua:370 and :397 keep passing for the wrong reason;
            :407 (journal sidecar asserts is_nil for M-o) fails outright. Kept Minor because step 1's
            collision guard and CI both catch these loudly.
            (carried from plan-quality PQ-10, deferred to the boundary review)
          family: doc-consumer-enumeration
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - "n": 2
      timestamp: "2026-09-08T19:16:06-07:00"
      agent: claude
      findings:
        - id: BR-3
          severity: Important
          title: The resolve arm stubs run_resolve wholesale; the injected-runner seam the Done-when promised is unreachable from goto_ref_at_cursor
          detail: |-
            artifact_ref.lua:208 calls M.run_resolve with three arguments, so the documented
            runner(argv, on_complete) seam is dead on the production path. open_reference_spec.lua:338
            therefore replaces artifact_ref.run_resolve itself, which means the test flow and the
            production flow do not share a boundary (ARCH-MOCK). Thread opts.runner through
            goto_ref_at_cursor and let the spec inject a fake returning canned `sdlc resolve --json`
            stdout; the same change retires the identical stub at artifact_ref_spec.lua:249-252.
          family: external-seam-not-shared
          round: 2
        - id: BR-4
          severity: Important
          title: vim.fn.expand on transcript-derived text executes backticks, reachable from the unified chain
          detail: |-
            Verified end-to-end through the real command: a chat line @@`touch <path> && echo /nope`@@
            with the cursor on it creates the file when <M-o> is pressed. ref_path comes from buffer
            content whose provenance is model output. Pre-existing (both deleted chains expanded the
            same value), but this diff makes it single-sited. Class enumeration: init.lua:4382 and
            init.lua:4396 (both derive from ref_path, so one guard after extraction covers both), plus
            the sibling consumer helper.find_files:313 reached via chat_respond.lua:847. Reject or
            escape a backtick in ref_path and degrade to "none"/warn rather than expanding.
          family: untrusted-path-expansion
          round: 2
        - id: BR-5
          severity: Important
          title: The is_chat directory divergence has no negative test; flattening it leaves the suite green
          detail: |-
            The Spec names D4 "the one that must NOT be flattened" and the Plan promises
            characterisation tests for all four arms. Mutating init.lua:4387 to `if true and (...)`
            -- flattening exactly that divergence -- leaves all 17 tests in open_reference_spec
            passing. Add the negative half: a directory reference in a MARKDOWN buffer must not issue
            Explore and must take the "failed"/warning exit.
          family: divergence-not-pinned
          round: 2
        - id: BR-6
          severity: Important
          title: focus_other_split swept two of three copies; open_buf still carries its own inline version
          detail: |-
            init.lua:4314 is a verbatim extraction of the block open_buf still holds at 2960-2984.
            The comment explains why a separate CALL SITE is needed (netrw does not go through
            open_buf) but not why the logic must be duplicated. Since ARCH-DRY is the stated
            rationale for the whole extraction, stopping at the two instances the issue named is
            instance-not-class. Move focus_other_split above open_buf and call it there.
          family: two-split-preference-duplicated
          round: 2
        - id: BR-7
          severity: Minor
          title: The glob-to-base-dir derivation duplicates helper.process_directory_pattern
          detail: |-
            init.lua:4395's gsub pair is a near-duplicate of helper.lua:370-379. Moved code rather
            than new, but it is the pure fragment that belongs in one tested helper -- and the
            counterexample to the Core-concepts table's "Pure entities: None".
          family: two-split-preference-duplicated
          round: 2
        - id: BR-8
          severity: Minor
          title: The sweep now skips `deleted` rows entirely instead of asserting the symbol is gone
          detail: |-
            single_source_sweeps_spec.lua:192 short-circuits the whole row, so a plan can mark a row
            deleted while the symbol survives. Stronger: for a deleted row, assert no definition
            exists. (open_chat_reference is in fact gone -- I grepped -- but the guard would not know.)
          family: divergence-not-pinned
          round: 2
        - id: BR-9
          severity: Minor
          title: The markdown "is mapped" list gained <M-s> but never <M-o>
          detail: |-
            keybinding_agreement_spec.lua:370 pins <C-g>ve/<M-s>/<M-CR> on a markdown buffer. The
            Done-when's "in both buffer types" is asserted at the command level only; the collision
            this issue fixed lived at the binding level.
          family: binding-level-coverage-gap
          round: 2
        - id: BR-10
          severity: Minor
          title: The <M-o> fall-through spawns sdlc resolve with no in-flight guard
          detail: |-
            init.lua:4475 routes the most-pressed key into an uncancelled subprocess; two presses
            before the first returns start two spawns and can open twice or show two pickers.
            Pre-existing on gf, but the key it now sits behind is pressed far more often
            (ARCH-CONSTRAINTS / ARCH-ORDER extent).
          family: unbounded-inflight-spawn
          round: 2
        - id: BR-11
          severity: Minor
          title: 'Chat''s chain order flipped: inline branch links now precede open_branch_ref'
          detail: "init.lua:4356-4358 adopts markdown's order. Observable only on a \U0001F33F: line that also\ncontains an inline [\U0001F33F:…](file) with the cursor inside it. Intentional, but not recorded\nin the divergence table or the Log."
          family: chain-order-change-unrecorded
          round: 2
        - id: BR-12
          severity: Minor
          title: Twelve unrelated workshop/parley transcripts were swept into implementation commit bb7050a
          detail: |-
            ~1,300 lines on pi history, special relativity and Io's orbital period landed in the
            commit titled "#225: one reference chain, three-valued...". git log --grep "^#225" now
            returns a commit whose diff is mostly unrelated prose (AGENTS.md section 12).
          family: commit-scope-hygiene
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-08T19:54:08-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: The unified file arm goes through open_buf, so the chat path gains file-tracking and window reuse; focus_other_split remains only for the netrw call site.
          round: 3
        - id: BR-2
          disposition: addressed
          note: Plan row now carries the grep-derived list (13 hits / 7 files) and keybinding_agreement + review_menu specs are updated; both suites pass.
          round: 3
        - id: BR-3
          disposition: addressed
          note: opts.runner threaded at artifact_ref.lua:233; artifact_ref_spec asserts the real argv, and the M-o test fakes vim.system rather than the module.
          round: 3
        - id: BR-4
          disposition: addressed
          note: The three named sites plus seven more are routed through helper.expand_path; the residual class outside the chat-navigation modules is raised new (see C3).
          round: 3
        - id: BR-5
          disposition: addressed
          note: 'Mutation-verified independently: `if true and (...)` at init.lua:4387 reddens exactly the new negative test.'
          round: 3
        - id: BR-6
          disposition: addressed
          note: open_buf calls focus_other_split; the inline block is gone. Unpinned by any test — noted under coverage, not re-raised.
          round: 3
        - id: BR-7
          disposition: addressed
          note: helper.glob_base plus an IO-free unit spec; process_directory_pattern now derives from it.
          round: 3
        - id: BR-8
          disposition: addressed
          note: The deleted row inverts, and I confirmed the matcher fires on a control symbol and stays silent on open_chat_reference.
          round: 3
        - id: BR-9
          disposition: addressed
          note: <M-o> added to the markdown mapped list; the journal-sidecar assertion correctly moved to <M-s>.
          round: 3
        - id: BR-10
          disposition: addressed
          note: Deferred deliberately and filed as parley.nvim#226 with a Done-when that reuses the runner seam; recorded in the issue Revisions.
          round: 3
        - id: BR-11
          disposition: addressed
          note: The chain-order flip is now recorded in the issue's Revisions with the reason the inline link is the better match.
          round: 3
        - id: BR-12
          disposition: addressed
          note: No workshop/parley paths appear in the pinned range; the transcripts are untracked again.
          round: 3
      findings:
        - id: BR-13
          severity: Critical
          title: make test is RED at HEAD — two new spec files are unrouted in atlas/traceability.yaml
          detail: |-
            tests/arch/single_source_sweeps_spec.lua "every spec this branch ADDED is routed somewhere"
            fails on tests/integration/untrusted_path_spec.lua and tests/unit/glob_base_spec.lua. It is
            the only failure in a 356-file run (lint clean), and this round's own fix commit caused it.
            2nd in family, so the RULE: the branch adds artifacts, the registry that indexes them must be
            dispositioned against a mechanical enumeration — and here the repo ALREADY encodes that
            enumeration as an arch guard. So the enforcing rule is narrower and cheaper than a checklist:
            `make test` must be green at the moment the boundary review is REQUESTED, not merely at the
            moment the previous round's ledger was written. The prior ledger's "full suite clean at HEAD"
            described a window three commits back.
          family: doc-consumer-enumeration
          round: 3
        - id: BR-14
          severity: Critical
          title: The BR-4 guard makes resolve_chat_path return nil; two callers index it and crash
          detail: "helper.lua:264 states the contract as \"callers treat nil as not usable and take their\nexisting not-found branch\". init.lua:4246 and init.lua:3292 instead raise \"attempt to index\nlocal 'expanded' (a nil value)\" — reproduced through the real M.cmd.OpenFileUnderCursor on a\nbackticked \U0001F33F: line and on a backticked inline [\U0001F33F:…](file). The security property holds (no\nmarker file), the degrade-visibly property does not. It shipped because untrusted_path_spec\nwraps the call in a bare pcall and asserts only the absent marker, so the test cannot\ndistinguish a clean refusal from a crash. Sweep the other resolve_chat_path consumers\n(init.lua:3325, :3348, :3445; exporter.lua:151, :180; highlighter.lua:66) and make each arm\nassert ok == true plus the expected warning."
          family: guard-nil-contract-unswept
          round: 3
        - id: BR-15
          severity: Critical
          title: outline.lua still executes backticks from a transcript-derived branch path — confirmed end-to-end
          detail: "2nd in family, so the ask is the RULE, not this site: a path parsed out of buffer text —\nanything derived from chat_parser output (branches[].path, parent_link.path, @@ refs, inline\nlinks) — may be expanded only via helper.expand_path, and the enumeration is\n`vim.fn.expand(<variable>)` in every module that consumes chat_parser output, enforced as an\narch test with an explicit config-derived allowlist rather than a memorised list. Measured:\nBR-4 named 3 sites, the fix found 10, and the residue is outline.lua:207/221/243/320 and\nexporter.lua:117/128/140/163. outline.lua:205 and chat_respond.lua:176 were byte-identical\n5-line resolve_path functions; the round guarded one and not the other — a 4th copy of the\nsame function, which is why instance-fixing keeps missing (ARCH-DRY + ARCH-PURPOSE).\nReproduced: a chat with \"\U0001F33F: ~/`touch <marker>`.md: Child\" driven through\noutline._build_tree_outline_items creates the marker. Reachable from <M-t>."
          family: untrusted-path-expansion
          round: 3
        - id: BR-16
          severity: Important
          title: Core-concepts table calls expand_path PURE; it expands the environment, globs the fs, and its tests are integration
          detail: |-
            workshop/issues/000225-open-link-alt-o.md:135 lists expand_path under "Pure entities", but
            helper.lua:270 calls vim.fn.expand and its only tests live in
            tests/integration/untrusted_path_spec.lua, needing a real Neovim and a real filesystem to
            observe the marker. glob_base in the row above IS pure and its spec proves it. Move the row
            to Integration points (wraps: vim.fn.expand) with a ## Revisions entry.
          family: pure-label-vs-io
          round: 3
        - id: BR-17
          severity: Important
          title: prepare_dir returns the unusable input on refusal while every sibling sink returns nil
          detail: |-
            helper.lua:611-615 returns odir (the backtick string) where read_file_content returns nil,
            is_directory false, find_files {} and expand_path nil. init.lua:826 assigns that return
            straight into M.config[k]. Unreachable today because that call site is config-derived, but it
            is inconsistent error handling introduced by this diff.
          family: guard-nil-contract-unswept
          round: 3
        - id: BR-18
          severity: Minor
          title: The @@ parser adopted markdown's [^@]+ form, narrowing chat for @-containing paths, unrecorded
          detail: |-
            init.lua:4358 replaces chat's greedy ^@@(.+)@@ with ^@@%s*([^@]+)@@, so @@/tmp/a@b/c.md@@ now
            falls to ^@@(.+)$ and carries a trailing @@ into the path, exiting "failed" instead of
            opening. It is a fifth resolved divergence and belongs in the Spec's table or the Log rather
            than only in the diff.
          family: divergence-not-pinned
          round: 3
        - id: BR-19
          severity: Minor
          title: review_menu(<M-s>) and skill_picker(<C-g>s) are two ids and two config keys for one action
          detail: |-
            keybinding_registry.lua:750 (markdown scope, config_key review_shortcut_menu) and :256 (global
            scope, config_key skill_shortcut) both call parley.skill_picker.open(). Now that the key is
            <M-s>, they are precisely the alt/<C-g> pair that open_file models as ONE entry with
            default_key = { "<M-o>", "<C-g>o" }. Pre-existing; the rename made it adjacent (ARCH-DRY).
          family: duplicate-registry-entry-one-action
          round: 3
        - id: BR-20
          severity: Minor
          title: atlas quotes a diagnostic the @@ arm no longer emits
          detail: "atlas/context/file_references.md:52 justifies the no-fall-through rule with \"Chat file not\nfound: …\", but the @@ arm now warns \"File not found: …\" (init.lua:4432). The \U0001F33F: arm still\nuses the old wording, so the doc is half-right."
          family: doc-consumer-enumeration
          round: 3
      blocked: true
---

# Gate ledger — parley.nvim#225 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-08T19:16:06-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `unbacked-existing-behavior-claim` Row 4 bundles "split-aware edit" with the Explore arm, but markdown already has it via open_buf
  3rd in family, so the ask is the RULE: an "X exists only in path A" claim must cite the
  ABSENCE in path B, not the presence in A. Measured prevalence 3. Here the cited range
  (init.lua:4463-4492) backs the directory Explore arm only; the chat chain's split-aware
  edit is at init.lua:4574-4597 and duplicates M.open_buf's logic (init.lua:2963-2984),
  which markdown already reaches. Keeping it behind is_chat carries the duplication through
  the extraction (ARCH-DRY); collapsing it onto open_buf also adds file-tracking
  (init.lua:2945-2946) and existing-window reuse (init.lua:2948-2958) to the chat path.
  (carried from plan-quality PQ-9, deferred to the boundary review)
- **BR-2** [Minor] `doc-consumer-enumeration` The M-o consumer list is recalled, not grep-derived; omits keybinding_registry.lua:750 and three keybinding_agreement_spec assertions
  2nd in family, so the RULE: a plan moving a key or identifier derives its update list from
  a grep of the literal and dispositions every hit, including each test asserting the old
  value as "will fail" / "passes for the wrong reason" / "unaffected". Measured: 13 hits in
  7 files, plan names 2 files. keybinding_registry.lua:750 is review_menu's functional
  default_key. keybinding_agreement_spec.lua:370 and :397 keep passing for the wrong reason;
  :407 (journal sidecar asserts is_nil for M-o) fails outright. Kept Minor because step 1's
  collision guard and CI both catch these loudly.
  (carried from plan-quality PQ-10, deferred to the boundary review)

## Round 2 — 2026-09-08T19:16:06-07:00 (claude) — BLOCKED

### Raised

- **BR-3** [Important] `external-seam-not-shared` The resolve arm stubs run_resolve wholesale; the injected-runner seam the Done-when promised is unreachable from goto_ref_at_cursor
  artifact_ref.lua:208 calls M.run_resolve with three arguments, so the documented
  runner(argv, on_complete) seam is dead on the production path. open_reference_spec.lua:338
  therefore replaces artifact_ref.run_resolve itself, which means the test flow and the
  production flow do not share a boundary (ARCH-MOCK). Thread opts.runner through
  goto_ref_at_cursor and let the spec inject a fake returning canned `sdlc resolve --json`
  stdout; the same change retires the identical stub at artifact_ref_spec.lua:249-252.
- **BR-4** [Important] `untrusted-path-expansion` vim.fn.expand on transcript-derived text executes backticks, reachable from the unified chain
  Verified end-to-end through the real command: a chat line @@`touch <path> && echo /nope`@@
  with the cursor on it creates the file when <M-o> is pressed. ref_path comes from buffer
  content whose provenance is model output. Pre-existing (both deleted chains expanded the
  same value), but this diff makes it single-sited. Class enumeration: init.lua:4382 and
  init.lua:4396 (both derive from ref_path, so one guard after extraction covers both), plus
  the sibling consumer helper.find_files:313 reached via chat_respond.lua:847. Reject or
  escape a backtick in ref_path and degrade to "none"/warn rather than expanding.
- **BR-5** [Important] `divergence-not-pinned` The is_chat directory divergence has no negative test; flattening it leaves the suite green
  The Spec names D4 "the one that must NOT be flattened" and the Plan promises
  characterisation tests for all four arms. Mutating init.lua:4387 to `if true and (...)`
  -- flattening exactly that divergence -- leaves all 17 tests in open_reference_spec
  passing. Add the negative half: a directory reference in a MARKDOWN buffer must not issue
  Explore and must take the "failed"/warning exit.
- **BR-6** [Important] `two-split-preference-duplicated` focus_other_split swept two of three copies; open_buf still carries its own inline version
  init.lua:4314 is a verbatim extraction of the block open_buf still holds at 2960-2984.
  The comment explains why a separate CALL SITE is needed (netrw does not go through
  open_buf) but not why the logic must be duplicated. Since ARCH-DRY is the stated
  rationale for the whole extraction, stopping at the two instances the issue named is
  instance-not-class. Move focus_other_split above open_buf and call it there.
- **BR-7** [Minor] `two-split-preference-duplicated` The glob-to-base-dir derivation duplicates helper.process_directory_pattern
  init.lua:4395's gsub pair is a near-duplicate of helper.lua:370-379. Moved code rather
  than new, but it is the pure fragment that belongs in one tested helper -- and the
  counterexample to the Core-concepts table's "Pure entities: None".
- **BR-8** [Minor] `divergence-not-pinned` The sweep now skips `deleted` rows entirely instead of asserting the symbol is gone
  single_source_sweeps_spec.lua:192 short-circuits the whole row, so a plan can mark a row
  deleted while the symbol survives. Stronger: for a deleted row, assert no definition
  exists. (open_chat_reference is in fact gone -- I grepped -- but the guard would not know.)
- **BR-9** [Minor] `binding-level-coverage-gap` The markdown "is mapped" list gained <M-s> but never <M-o>
  keybinding_agreement_spec.lua:370 pins <C-g>ve/<M-s>/<M-CR> on a markdown buffer. The
  Done-when's "in both buffer types" is asserted at the command level only; the collision
  this issue fixed lived at the binding level.
- **BR-10** [Minor] `unbounded-inflight-spawn` The <M-o> fall-through spawns sdlc resolve with no in-flight guard
  init.lua:4475 routes the most-pressed key into an uncancelled subprocess; two presses
  before the first returns start two spawns and can open twice or show two pickers.
  Pre-existing on gf, but the key it now sits behind is pressed far more often
  (ARCH-CONSTRAINTS / ARCH-ORDER extent).
- **BR-11** [Minor] `chain-order-change-unrecorded` Chat's chain order flipped: inline branch links now precede open_branch_ref
  init.lua:4356-4358 adopts markdown's order. Observable only on a 🌿: line that also
  contains an inline [🌿:…](file) with the cursor inside it. Intentional, but not recorded
  in the divergence table or the Log.
- **BR-12** [Minor] `commit-scope-hygiene` Twelve unrelated workshop/parley transcripts were swept into implementation commit bb7050a
  ~1,300 lines on pi history, special relativity and Io's orbital period landed in the
  commit titled "#225: one reference chain, three-valued...". git log --grep "^#225" now
  returns a commit whose diff is mostly unrelated prose (AGENTS.md section 12).

## Round 3 — 2026-09-08T19:54:08-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — The unified file arm goes through open_buf, so the chat path gains file-tracking and window reuse; focus_other_split remains only for the netrw call site.
- BR-2 — addressed — Plan row now carries the grep-derived list (13 hits / 7 files) and keybinding_agreement + review_menu specs are updated; both suites pass.
- BR-3 — addressed — opts.runner threaded at artifact_ref.lua:233; artifact_ref_spec asserts the real argv, and the M-o test fakes vim.system rather than the module.
- BR-4 — addressed — The three named sites plus seven more are routed through helper.expand_path; the residual class outside the chat-navigation modules is raised new (see C3).
- BR-5 — addressed — Mutation-verified independently: `if true and (...)` at init.lua:4387 reddens exactly the new negative test.
- BR-6 — addressed — open_buf calls focus_other_split; the inline block is gone. Unpinned by any test — noted under coverage, not re-raised.
- BR-7 — addressed — helper.glob_base plus an IO-free unit spec; process_directory_pattern now derives from it.
- BR-8 — addressed — The deleted row inverts, and I confirmed the matcher fires on a control symbol and stays silent on open_chat_reference.
- BR-9 — addressed — <M-o> added to the markdown mapped list; the journal-sidecar assertion correctly moved to <M-s>.
- BR-10 — addressed — Deferred deliberately and filed as parley.nvim#226 with a Done-when that reuses the runner seam; recorded in the issue Revisions.
- BR-11 — addressed — The chain-order flip is now recorded in the issue's Revisions with the reason the inline link is the better match.
- BR-12 — addressed — No workshop/parley paths appear in the pinned range; the transcripts are untracked again.

### Raised

- **BR-13** [Critical] `doc-consumer-enumeration` make test is RED at HEAD — two new spec files are unrouted in atlas/traceability.yaml
  tests/arch/single_source_sweeps_spec.lua "every spec this branch ADDED is routed somewhere"
  fails on tests/integration/untrusted_path_spec.lua and tests/unit/glob_base_spec.lua. It is
  the only failure in a 356-file run (lint clean), and this round's own fix commit caused it.
  2nd in family, so the RULE: the branch adds artifacts, the registry that indexes them must be
  dispositioned against a mechanical enumeration — and here the repo ALREADY encodes that
  enumeration as an arch guard. So the enforcing rule is narrower and cheaper than a checklist:
  `make test` must be green at the moment the boundary review is REQUESTED, not merely at the
  moment the previous round's ledger was written. The prior ledger's "full suite clean at HEAD"
  described a window three commits back.
- **BR-14** [Critical] `guard-nil-contract-unswept` The BR-4 guard makes resolve_chat_path return nil; two callers index it and crash
  helper.lua:264 states the contract as "callers treat nil as not usable and take their
  existing not-found branch". init.lua:4246 and init.lua:3292 instead raise "attempt to index
  local 'expanded' (a nil value)" — reproduced through the real M.cmd.OpenFileUnderCursor on a
  backticked 🌿: line and on a backticked inline [🌿:…](file). The security property holds (no
  marker file), the degrade-visibly property does not. It shipped because untrusted_path_spec
  wraps the call in a bare pcall and asserts only the absent marker, so the test cannot
  distinguish a clean refusal from a crash. Sweep the other resolve_chat_path consumers
  (init.lua:3325, :3348, :3445; exporter.lua:151, :180; highlighter.lua:66) and make each arm
  assert ok == true plus the expected warning.
- **BR-15** [Critical] `untrusted-path-expansion` outline.lua still executes backticks from a transcript-derived branch path — confirmed end-to-end
  2nd in family, so the ask is the RULE, not this site: a path parsed out of buffer text —
  anything derived from chat_parser output (branches[].path, parent_link.path, @@ refs, inline
  links) — may be expanded only via helper.expand_path, and the enumeration is
  `vim.fn.expand(<variable>)` in every module that consumes chat_parser output, enforced as an
  arch test with an explicit config-derived allowlist rather than a memorised list. Measured:
  BR-4 named 3 sites, the fix found 10, and the residue is outline.lua:207/221/243/320 and
  exporter.lua:117/128/140/163. outline.lua:205 and chat_respond.lua:176 were byte-identical
  5-line resolve_path functions; the round guarded one and not the other — a 4th copy of the
  same function, which is why instance-fixing keeps missing (ARCH-DRY + ARCH-PURPOSE).
  Reproduced: a chat with "🌿: ~/`touch <marker>`.md: Child" driven through
  outline._build_tree_outline_items creates the marker. Reachable from <M-t>.
- **BR-16** [Important] `pure-label-vs-io` Core-concepts table calls expand_path PURE; it expands the environment, globs the fs, and its tests are integration
  workshop/issues/000225-open-link-alt-o.md:135 lists expand_path under "Pure entities", but
  helper.lua:270 calls vim.fn.expand and its only tests live in
  tests/integration/untrusted_path_spec.lua, needing a real Neovim and a real filesystem to
  observe the marker. glob_base in the row above IS pure and its spec proves it. Move the row
  to Integration points (wraps: vim.fn.expand) with a ## Revisions entry.
- **BR-17** [Important] `guard-nil-contract-unswept` prepare_dir returns the unusable input on refusal while every sibling sink returns nil
  helper.lua:611-615 returns odir (the backtick string) where read_file_content returns nil,
  is_directory false, find_files {} and expand_path nil. init.lua:826 assigns that return
  straight into M.config[k]. Unreachable today because that call site is config-derived, but it
  is inconsistent error handling introduced by this diff.
- **BR-18** [Minor] `divergence-not-pinned` The @@ parser adopted markdown's [^@]+ form, narrowing chat for @-containing paths, unrecorded
  init.lua:4358 replaces chat's greedy ^@@(.+)@@ with ^@@%s*([^@]+)@@, so @@/tmp/a@b/c.md@@ now
  falls to ^@@(.+)$ and carries a trailing @@ into the path, exiting "failed" instead of
  opening. It is a fifth resolved divergence and belongs in the Spec's table or the Log rather
  than only in the diff.
- **BR-19** [Minor] `duplicate-registry-entry-one-action` review_menu(<M-s>) and skill_picker(<C-g>s) are two ids and two config keys for one action
  keybinding_registry.lua:750 (markdown scope, config_key review_shortcut_menu) and :256 (global
  scope, config_key skill_shortcut) both call parley.skill_picker.open(). Now that the key is
  <M-s>, they are precisely the alt/<C-g> pair that open_file models as ONE entry with
  default_key = { "<M-o>", "<C-g>o" }. Pre-existing; the rename made it adjacent (ARCH-DRY).
- **BR-20** [Minor] `doc-consumer-enumeration` atlas quotes a diagnostic the @@ arm no longer emits
  atlas/context/file_references.md:52 justifies the no-fall-through rule with "Chat file not
  found: …", but the @@ arm now warns "File not found: …" (init.lua:4432). The 🌿: arm still
  uses the old wording, so the doc is half-right.

## Open findings

- **BR-13** [Critical] `doc-consumer-enumeration` make test is RED at HEAD — two new spec files are unrouted in atlas/traceability.yaml
- **BR-14** [Critical] `guard-nil-contract-unswept` The BR-4 guard makes resolve_chat_path return nil; two callers index it and crash
- **BR-15** [Critical] `untrusted-path-expansion` outline.lua still executes backticks from a transcript-derived branch path — confirmed end-to-end
- **BR-16** [Important] `pure-label-vs-io` Core-concepts table calls expand_path PURE; it expands the environment, globs the fs, and its tests are integration
- **BR-17** [Important] `guard-nil-contract-unswept` prepare_dir returns the unusable input on refusal while every sibling sink returns nil
- **BR-18** [Minor] `divergence-not-pinned` The @@ parser adopted markdown's [^@]+ form, narrowing chat for @-containing paths, unrecorded
- **BR-19** [Minor] `duplicate-registry-entry-one-action` review_menu(<M-s>) and skill_picker(<C-g>s) are two ids and two config keys for one action
- **BR-20** [Minor] `doc-consumer-enumeration` atlas quotes a diagnostic the @@ arm no longer emits
