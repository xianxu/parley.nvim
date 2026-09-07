# Boundary Review — parley.nvim#214 (milestone M1)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 54a5c7a2ecaa3faf268d867f5222e73bd6f1dafb..25ac7e45c37578425eb2262208a2b8e85030c2e9 |
| command | sdlc milestone-close --issue 214 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-06T08:43:15-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1's structural work is largely right — the chords land in `config.lua` where `resolve_keys` actually reads them (the PQ-1 trap avoided), the four branch functions collapse into one `branch_inserters`, tool folds become callable without being bound, and the atlas gains a genuinely useful "Resolution" section. But the milestone's headline decision — *create the child immediately and open it, so the no-selection case is a redirected submission* — is defeated in one argument: `insert_plain` passes `""` as the topic, and parley's auto-topic generator fires only on `topic == "?"`. I verified the written file: every `<M-i>` branch is a permanently untitled `<timestamp>.md` that never gets a slug and whose parent ref line reads `🌿: 2026-…md: ` forever. That contradicts the code comment ("Verified, not assumed"), the atlas, and the plan-gate's PQ-2 disposition ("degrades to the same shape as an abandoned `<C-g>c` chat" — `<C-g>c` ships `topic: ?`). It's a one-token fix plus a test, but it must land before the boundary. Secondary blockers are cheap: no test touches `branch_ref.lua` or `branch_inserters` at all, and the four new chord tests stay green with `config.lua`'s entry deleted because the registry now carries a duplicate of the same key list.

## 1. Strengths

- **`config.lua` as the list-carrying artifact is correct and non-obvious.** `keybinding_registry.lua:971` really does return `default_key` only when there is no `config_key`; putting the chords in the registry would have been inert for `chat_prune`. Verified by probing `resolve_keys` directly.
- **`config.lua:355-362` records *why* `<M-i>` leads `<M-S-CR>`** (help renders `keys[1]`; most terminals cannot distinguish Shift+Enter). The reversal against the operator-approved order was flagged in `## Log` rather than done quietly — right call, right disclosure.
- **The tests assert the full key *list*, not `keys[1]`** (`keybindings_spec.lua:266-278`, `config_tools_spec.lua:386-389`). That is exactly the shrink class PQ-1 named, and asserting `keys[1]` would have stayed green while an alias vanished.
- **`atlas/ui/keybindings.md` "Unbound but callable"** is a genuinely good piece of architectural writing — it names the distinction (`unbound ≠ unreachable`) and pins it with `chat_toggle_tool_folds = M.cmd.ToggleToolFolds` at `init.lua:2336` so binding cannot drift from calling.
- **`branch_ref.lua`'s pure/IO split is the right shape** — line editing separated from file creation and window focus. The module just needs the tests its own docstring promises.

## 2. Critical findings

**`init.lua:2096` — the branched child ships `topic:` empty, so it is never titled and never slugged.**

```lua
M.create_child_chat(new_chat_file, "", buf, nil)   -- → header becomes "topic: " (empty)
```

`create_child_chat` does `template:gsub("topic: %?", "topic: " .. topic)`; with `topic = ""` the `?` sentinel is consumed. Measured output of a real `create_child_chat(child, '', pb, nil)`:

```
---
topic: 
file: 2026-02-02.11-11-11.111.md
```

Downstream, both lifecycle triggers key off `?`:
- `chat_respond.lua:1934` — `if headers.topic == "?" then` … auto-topic generation. Never fires.
- `init.lua:2652` — `_slug_rename_chat` returns `"no topic"` for `""`. Never renames.

So the child stays `2026-02-02.11-11-11.111.md` with no title, the chat finder shows it untitled, and the parent's line stays `🌿: 2026-02-02.11-11-11.111.md: `. The docstring at `init.lua:2073-2078` is self-refuting — "gains its slug on first write (the `ParleySlug` autocmd, **which skips an empty or `?` topic**)". The autocmd skipping it is the bug, not the mechanism.

Fix: pass `"?"` (the gsub becomes a no-op, auto-topic + slug rename both work, matching `<C-g>c`), and add a test asserting the created child's header line is `topic: ?` — that test goes red against the current `""`.

## 3. Important findings

**`lua/parley/branch_ref.lua` — the new pure module has zero tests, and is absent from `atlas/traceability.yaml`.** The module docstring justifies its existence as "testable without a filesystem (ARCH-PURE)"; `grep -rn branch_ref tests/` returns only keybinding-name matches. `splice_inline_link` (`start_col > end_col`, multibyte prefix, a selection containing `](`), `format_ref_line` with `nil` topic, `topic_for_selection` quoting — all uncovered. `atlas/traceability.yaml:141-150` still lists only the four old files under `chat/inline_branch_links`, so `make test-changed` will not route changes to this module anywhere. ARCH-PURE.

**`keybindings_spec.lua:320-323` stays green with the M1 fix reverted.** `branch_ref` now carries `default_key = { "<M-i>", "<M-S-CR>", "<C-g>i" }` at `keybinding_registry.lua:478` *and* the identical list at `config.lua:362`. Measured `resolve_keys` with the config key absent, a table with no `shortcut`, a bare string, and `shortcut = ""` — all four return the full default list. So deleting `config.lua:362` leaves all four new chord tests passing. This also breaks the convention the same spec file asserts: `keybindings_spec.lua:270` requires `assert.is_nil(entry.default_key)` for the config-resolved entries (`super_repo_toggle`, `chat_prune`, whose registry rows carry no `default_key`). Either drop `branch_ref`'s `default_key` to match, or make the test resolve against a config that lacks the key and assert it differs.

**`init.lua:2132-2136` — `branch_inserters(...).i` is dead at zero call sites, and the chat visual path double-`<Esc>`s.** The helper returns a complete `{n, i, v}` mode table, but both call sites rebuild their own wrappers: `:2295-2298` and `:2497-2500` each re-implement `stopinsert` + `.n()`, and `:2299-2302` wraps `.v` in an `<Esc>` that `insert_inline` already performs at `:2110`. The unification advertises three modes and delivers one. Fix: `branch_ref = chat_branch` / `branch_ref = md_branch` and delete both wrapper blocks. ARCH-DRY.

**Three copies of the branch-line formatter survive the consolidation.** `branch_ref.format_ref_line` (1 caller, `:2092`), `format_branch_ref` at `init.lua:2056` — byte-identical logic, 20 lines above it, 2 callers at `:3231` and `:3859` — and a third inlined in `create_child_chat` at `:4535` (`branch_prefix .. " " .. parent_rel .. ": " .. parent_topic`). PQ-3 asked for "one shared helper both families collapse into"; the diff added a fourth source instead of retiring the other three. Point `format_branch_ref` and `create_child_chat`'s `back_link` at `br.format_ref_line`. The repo already has the guard idiom for this — `tests/arch/single_source_sweeps_spec.lua` opens with "a sweep without a guard is a snapshot: it says nothing about the ninth copy" — and this consolidation got no row. ARCH-DRY, ARCH-PURPOSE.

**README.md is not updated for the primary-key change.** `README.md:156` documents ``<C-g>b`` for branch/prune and `:168` documents ``<C-g>i`` for branch; both are now legacy aliases, and `<C-g>?` advertises `<M-p>` / `<M-i>` (confirmed by dumping the live help). `:168` also still describes the normal-mode action as "insert a fork in the chat tree" — it now creates the child file *and* switches the window to it. Docs update gate.

**`atlas/ui/keybindings.md` misdescribes `resolve_keys`, and the same overstatement is now a code comment.** The new section says resolution "**replaces**, it does not merge **or fall back**" and that adding a `config_key` "silently **discards** whatever `default_key` held", quoting the `if not entry.config_key` early return. That is the wrong branch. Measured: with the config key absent, a table without `shortcut`, a bare string, or `shortcut = ""`, `resolve_keys` returns `default_key` in full. Only a table with a non-empty `shortcut` replaces. `keybinding_registry.lua:474-477` repeats the same claim ("ignores `default_key` entirely once a config_key exists"). This matters for M2 — the guard shape depends on which is true.

**`atlas/ui/keybindings.md` states the M2 superset guard in the present tense.** "An arch guard asserts the shipped config resolves to a superset of `default_key`." `grep -rn superset lua/ tests/` → no hits. That guard is an unchecked M2 row. Atlas is required to be current state, not planned state.

**`branch_ref` is rebindable but still not disableable.** Done-when: "Every binding parley registers is rebindable and disableable through config." Measured: `chat_shortcut_branch_ref = { shortcut = "" }` resolves to the default three keys, because the empty string falls through to `default_key`. `chat_toggle_tool_folds` only works because its `default_key` is nil. M2's `resolve_keys` strategy row owns the fix; flagging it here so the M2 guard is written to cover it rather than only the shrink direction. `config-shadows-default-key`.

**A child branched from a markdown buffer gets an unresolvable parent back-link.** `create_child_chat:4534` writes `parent_rel = fnamemodify(parent_path, ":t")`, and `get_chat_topic` returns nil at `init.lua:2402` for any basename not matching `^%d%d%d%d-%d%d-%d%d`. From the child (in `chat_dir`), `resolve_chat_path` tries `chat_dir/<md basename>` and every chat root, then the fuzzy path — which needs a parseable timestamp and gets nil. So the back-link dead-ends. Pre-existing for the markdown *visual* path; this diff makes the markdown *normal/insert* path create children too, so it is now reachable from the key the atlas documents as the primary branch action.

## 4. Minor findings

- `config_tools_spec.lua:434` — test titled "the keybinding callback and the command are the same function" asserts only `assert.is_function(parley.cmd.ToggleToolFolds)`. Reverting `chat_toggle_tool_folds = M.cmd.ToggleToolFolds` to an inline closure leaves it green. Assert identity against the registry callback table.
- `keybindings_spec.lua:335` asserts only the *absence* of `<M-S-CR>` in the help line; a regression to `<C-g>i` first would pass. Assert `<M-i>` positively.
- `init.lua:1072` — the pre-existing `-- Toggle server-side web_search tool per chat` comment now sits above `ToggleToolFolds`, and `ToggleWebSearch` at `:1083` has none.
- `init.lua:2474` — stale comment survived: "Branch ref helpers (markdown-specific: uses `format_branch_ref` and absolute paths)" immediately above the new shared-helper comment.
- Atlas line citations already drift: `init.lua:2812-2816` → the fuzzy fallback is at `:2822`; `keybinding_registry.lua:965` → the quoted return is at `:971`.
- `init.lua:2089,2106` — `insert_plain` computes `link` from `new_target()` and returns it; no caller reads it. It also *ignores* `abs_link`, always writing the basename — which contradicts the helper's own docstring ("a markdown file elsewhere needs the full path"). Behavior matches the old code, so this is a docstring/parameter-contract mismatch, not a regression.
- `:ParleyToggleToolFolds` toggles `vim.wo.foldenable` on whatever window is current, including non-chat buffers.
- ARCH-ORDER: `insert_plain`'s `i` path issues `stopinsert` (effective at the next main-loop pass) and then `vim.schedule`s `edit` + `startinsert!`; there is no seam to inject or observe that ordering, and no test exercises any interleaving.

## 5. Test coverage notes

Both touched spec files run green (`keybindings_spec` 28/0/0, `config_tools_spec` 26/0/0), as do `inline_branch_spec` (15/0/0) and `tree_export_spec`; `luacheck` is clean on both changed Lua files. The gap is what is *not* covered: `branch_ref.lua` (0 tests), `branch_inserters` (0 tests), and therefore the entire no-selection create-and-open path — which is where the Critical shipped. The kind of bug this diff could ship is precisely "the created child is in the wrong initial state", and nothing observes the created file. A single unit test reading back `create_child_chat`'s output for the no-selection path catches it, and would have caught it today.

Per the claimed-fix protocol: of M1's four `[x]` rows, row 1 is pinned by tests that do not actually discriminate the fix (see above), row 2 (unification) is pinned by nothing, row 3 (create-and-open) is pinned by nothing and is broken, row 4 (tool folds) is pinned by three tests, one of which does not assert its own title.

## 6. Architectural notes for upcoming work

- **ARCH-DRY** — flag (three surviving formatter copies; `.i` dead at zero call sites; the key list duplicated across `config.lua:362` and `keybinding_registry.lua:478`).
- **ARCH-PURE** — flag (pure module extracted with testability as its stated justification, zero tests). The split itself is the right shape.
- **ARCH-PURPOSE** — flag (the Critical defeats M1's stated purpose; PQ-3's `fix-the-class-not-the-site` sweep left two of the four copies of the formatter class in the tree).
- **ARCH-MOCK** — pass. No new external binary or service; filesystem writes go through the existing harness `HOME`/`TMPDIR` seam.
- **ARCH-CONSTRAINTS** — pass. Keystroke path is one template render + one `writefile` + one `:edit`; `get_chat_topic` is mtime-cached; no fan-out.
- **ARCH-SECURE** — pass. `fnameescape` on the `:edit` at `:2102`. No credentials. Buffer text is spliced into a markdown link unescaped (`](` in a selection breaks the link) — pre-existing, low impact.
- **ARCH-ORDER** — flag, minor. See the `stopinsert`/`schedule(startinsert)` note above. For M2, the abandonment cases PQ-2 raised are now materially different: the child file exists on disk *before* the parent's ref line is saved, so undoing the ref line or closing the parent leaves an orphan — and with the Critical unfixed, a permanently untitled one.

For M2 specifically: write the superset guard against the *measured* semantics, not the atlas's. Because `resolve_keys` falls back to `default_key` whenever the config value is missing, non-table, or has an empty/absent `shortcut`, a guard comparing "shipped config resolves to a superset of `default_key`" is vacuously true for any entry whose config default is malformed — which is the shape it most needs to catch.

## 7. Plan revision recommendations

Append a `## Revisions` entry to `workshop/issues/000214-curate-default-keybindings.md`:

1. **Config key name.** The M1 row specifies `global_shortcut_branch_ref`; the code ships `chat_shortcut_branch_ref` (`config.lua:362`, `keybinding_registry.lua:473`). The code is right — every `parley_buffer`-scope entry uses the `chat_shortcut_*` prefix (`open_file`, `resolve_ref_gf`, `resolve_ref_project`, `copy_fence`). Correct the row.
2. **Key order.** The M1 row specifies `{ "<M-S-CR>", "<M-i>", "<C-g>i" }`; the code ships `<M-i>` first. The `## Log` explains why, but the Plan row still states the superseded order.
3. **`default_key` retention.** The plan does not say whether a config-resolved entry keeps its `default_key`. `chat_prune` and `super_repo_toggle` carry none (and `keybindings_spec.lua:270` asserts that); `branch_ref` now carries a full duplicate. If it is retained deliberately as the input to M2's superset guard, say so — and note that the guard is then vacuous for the two entries that have no `default_key`.
4. **M2 `resolve_keys` row.** Record the measured fallback matrix (absent / non-table / table-without-`shortcut` / empty-string all resolve to `default_key`) so the M2 test strategy and the arch guard are written against it, and so the "disableable" Done-when is not certified by an empty string that does not disable.

```findings
findings:
  - id: new
    severity: Critical
    family: created-artifact-skips-lifecycle-trigger
    title: |
      Branched child ships an empty topic, so it is never auto-titled and never slugged
    detail: |
      init.lua:2096 passes "" to create_child_chat, whose gsub consumes the
      `topic: ?` sentinel and writes `topic: ` (verified by running it). Auto-topic
      generation fires only on `headers.topic == "?"` (chat_respond.lua:1934) and
      _slug_rename_chat bails on "" (init.lua:2652), so every <M-i> branch is a
      permanently untitled <timestamp>.md and the parent's ref line stays
      `🌿: ...md: ` forever. Contradicts the docstring at init.lua:2073-2078, the
      atlas, and PQ-2's disposition. Pass "?" and pin it with a test on the
      created header.
  - id: new
    severity: Important
    family: pure-extraction-without-tests
    title: |
      New pure module lua/parley/branch_ref.lua has zero tests and is absent from traceability.yaml
    detail: |
      The module docstring justifies its existence as "testable without a
      filesystem (ARCH-PURE)"; no test references it. splice_inline_link
      (start_col > end_col, multibyte prefix, a selection containing "]("),
      format_ref_line with nil topic, and topic_for_selection are all uncovered.
      atlas/traceability.yaml:141-150 still lists only the four old files, so
      make test-changed routes changes to this module nowhere.
  - id: new
    severity: Important
    family: test-does-not-pin-the-fix
    title: |
      The four M1 chord tests stay green if config.lua's chat_shortcut_branch_ref is deleted
    detail: |
      keybinding_registry.lua:478 now carries the same key list as config.lua:362.
      Measured resolve_keys with the config key absent, a table without shortcut,
      a bare string, and shortcut = "" — all four return the full default list. So
      the assertion cannot tell which artifact carries the list, which was PQ-1's
      whole point. It also breaks the convention keybindings_spec.lua:270 asserts
      (config-resolved entries carry no default_key, as chat_prune and
      super_repo_toggle do).
  - id: new
    severity: Important
    family: duplicate-helper-not-retired
    title: |
      branch_inserters(...).i is dead at zero call sites and the chat visual path double-Escs
    detail: |
      init.lua:2132-2136 returns a complete {n,i,v} table, but both call sites
      rebuild their own wrappers (:2295-2298, :2497-2500 re-implement stopinsert +
      .n(); :2299-2302 wraps .v in an Esc that insert_inline already does at
      :2110). The unified helper advertises three modes and delivers one. Pass
      chat_branch / md_branch directly and delete the wrappers.
  - id: new
    severity: Important
    family: duplicate-helper-not-retired
    title: |
      Three copies of the branch-line formatter survive the consolidation
    detail: |
      branch_ref.format_ref_line has one caller (:2092); format_branch_ref at
      init.lua:2056 is byte-identical logic 20 lines above it with two callers
      (:3231, :3859); create_child_chat inlines a third at :4535. PQ-3 asked for
      one shared helper both families collapse into. Point the other two at
      br.format_ref_line and add a row to tests/arch/single_source_sweeps_spec.lua,
      whose own preamble says a sweep without a guard is a snapshot.
  - id: new
    severity: Important
    family: readme-missing-for-changed-surface
    title: |
      README still documents the superseded primary keys and the old normal-mode behavior
    detail: |
      README.md:156 documents <C-g>b for branch/prune and :168 documents <C-g>i for
      branch; both are now legacy aliases and the help float advertises <M-p> /
      <M-i> (confirmed against the live help output). README:168 also still says
      "insert a fork in the chat tree" — the normal-mode path now creates the child
      file and switches the window to it.
  - id: new
    severity: Important
    family: docs-assert-unverified-behavior
    title: |
      New atlas Resolution section misdescribes resolve_keys, and the registry comment repeats it
    detail: |
      atlas/ui/keybindings.md says resolution "does not merge or fall back" and
      that adding a config_key "silently discards whatever default_key held",
      quoting the `if not entry.config_key` early return — the wrong branch.
      Measured: absent config key, table without shortcut, bare string, and
      shortcut = "" all return default_key in full; only a table with a non-empty
      shortcut replaces. keybinding_registry.lua:474-477 states the same
      overstatement. M2's guard shape depends on which is true.
  - id: new
    severity: Important
    family: docs-assert-unverified-behavior
    title: |
      Atlas states the M2 superset guard in the present tense, but it does not exist
    detail: |
      atlas/ui/keybindings.md: "An arch guard asserts the shipped config resolves
      to a superset of default_key." grep -rn superset lua/ tests/ returns nothing —
      that is an unchecked M2 plan row. Atlas is current state, not planned state.
  - id: new
    severity: Important
    family: config-shadows-default-key
    title: |
      branch_ref gained a config_key but still cannot be disabled
    detail: |
      Done-when requires every registered binding to be "rebindable and
      disableable through config". Measured: chat_shortcut_branch_ref =
      { shortcut = "" } resolves to the default three keys, because the empty
      string falls through to default_key. chat_toggle_tool_folds only disables
      because its default_key is nil. M2's resolve_keys row owns the fix; raising
      it so the M2 guard covers the disable direction, not only the shrink one.
  - id: new
    severity: Important
    family: reference-written-in-unresolvable-form
    title: |
      A child branched from a markdown buffer gets an unresolvable parent back-link
    detail: |
      create_child_chat:4534 writes the parent's basename, and get_chat_topic
      returns nil at init.lua:2402 for any basename not matching ^%d%d%d%d-%d%d-%d%d.
      From the child in chat_dir, resolve_chat_path tries chat_dir/<md basename>
      and every chat root, then the fuzzy path, which needs a parseable timestamp.
      Pre-existing for the markdown visual path; this diff makes the markdown
      normal/insert path create children too, so it is now reachable from the key
      the atlas documents as the primary branch action.
  - id: new
    severity: Minor
    family: test-does-not-pin-the-fix
    title: |
      config_tools_spec.lua:434 asserts is_function, not the identity its title claims
    detail: |
      Reverting chat_toggle_tool_folds = M.cmd.ToggleToolFolds to an inline
      closure leaves the test green. Assert identity against the registry callback.
  - id: new
    severity: Minor
    family: test-does-not-pin-the-fix
    title: |
      keybindings_spec.lua:335 asserts only the absence of <M-S-CR>, so <C-g>i first would pass
  - id: new
    severity: Minor
    family: stale-comment-after-move
    title: |
      init.lua:1072 web_search comment now sits above ToggleToolFolds; ToggleWebSearch has none
  - id: new
    severity: Minor
    family: stale-comment-after-move
    title: |
      init.lua:2474 still reads "markdown-specific: uses format_branch_ref and absolute paths"
  - id: new
    severity: Minor
    family: volatile-line-citations-in-docs
    title: |
      Atlas line citations already drift: init.lua:2812-2816 is now :2822, registry:965 is now :971
  - id: new
    severity: Minor
    family: dead-value-in-new-code
    title: |
      insert_plain returns an unused `link` and ignores abs_link, contradicting its own docstring
    detail: |
      init.lua:2089,2106 compute and return `link` that no caller reads, and the
      plain path always writes the basename — so the helper's "a markdown file
      elsewhere needs the full path" contract holds only on the inline path.
      Behavior matches the old code, so this is a contract/docstring mismatch.
  - id: new
    severity: Minor
    family: command-not-scoped-to-context
    title: |
      :ParleyToggleToolFolds toggles vim.wo.foldenable in any window, including non-chat buffers
  - id: new
    severity: Minor
    family: no-seam-for-ordering
    title: |
      insert_plain's stopinsert then schedule(edit + startinsert!) has no seam to inject or observe
    detail: |
      ARCH-ORDER: the i-mode path issues stopinsert (effective at the next
      main-loop pass) and then schedules startinsert!. No test exercises any
      interleaving of that sequence, and there is no way to reproduce a reported
      ordering failure.
```

---

## Re-review — 2026-09-06T09:15:13-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 54a5c7a2ecaa3faf268d867f5222e73bd6f1dafb..8ade807e20bcaf0e5ff0d5de5b96327ada29b0a0 |
| command | sdlc milestone-close --issue 214 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-06T09:15:13-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The M1 substance is real and, where it is pinned, well pinned: the chord change lives in `config.lua` (the artifact `resolve_keys` actually reads), the `?` sentinel fix is driven from the call site rather than the callee, `branch_ref.lua` is genuinely pure, and the atlas resolution table was rewritten from measurement after the last round proved the old claim wrong. Full suite green (351 files linted, 0 warnings/errors; every spec PASS). What blocks SHIP is two things. First, a new Critical on the milestone's headline path: `insert_plain` writes the child to disk, inserts the parent's `🌿:` line **without saving the parent**, then navigates away — so the on-disk tree is inconsistent the moment you press `<M-i>`, and under `'nohidden'` the `:edit` raises a raw `E37` Lua stack trace and the switch silently fails. Second, seven of the eighteen prior findings did not survive verification: three fixes (BR-10, BR-11, BR-17) leave the entire suite green when reverted, BR-4 and BR-5 fixed the site the finding named and left the enumerable siblings in the tree, BR-2's traceability half was skipped, and BR-15's class recurred inside the same commit that fixed its instance.

## 1. Strengths

- **`tests/unit/keybindings_spec.lua:330` pins the shipped artifact, not the merged table.** `dofile("lua/parley/config.lua")` is the right move for BR-3 — verified by deleting `chat_shortcut_branch_ref` from `config.lua`: the test goes red where every `parley.config`-reading assertion stays green.
- **BR-1 is pinned at the call site.** `tests/integration/branch_child_spec.lua:78` drives `_branch_inserters(buf, false).n()`. Verified by reverting `"?"` → `""`: that test goes red while the three `create_child_chat` tests stay green — exactly the split the spec's own preamble predicts.
- **`lua/parley/branch_ref.lua` is genuinely PURE** (ARCH-PURE pass): `tests/unit/branch_ref_spec.lua` runs with no filesystem, no buffer, no config, no mocks.
- **`atlas/ui/keybindings.md:33-46` is measured, not inferred.** Six config shapes, each with a verified outcome; I re-measured `resolve_keys` against all six and the table is correct. `keybinding_registry.lua:472-477` was corrected to match, and the false superset claim is gone (`grep -rn superset atlas/ lua/ tests/` → nothing).
- **The `<M-i>`-before-`<M-S-CR>` ordering call is defended from both sides** (`keybindings_spec.lua:317,345`). Verified by reordering the shipped list to `{ "<C-g>i", "<M-i>", "<M-S-CR>" }`: three tests go red.

## 2. Critical findings

**`lua/parley/init.lua:2095-2125` — the branch path commits the child to disk but not the parent's link, and errors out under `'nohidden'`.**

Measured, in a real chat buffer:

```
parent modified right after n():        true
parent ON DISK still has no ref line:   true
child ON DISK:                          2026-…md  (with back-link)
```

and with `set nohidden`:

```
Error executing vim.schedule lua callback: … Vim(edit):E37: No write since last change
  ./lua/parley/init.lua:2122
switched away: false
```

So on the default path the tree is inconsistent from the keypress onward — the child is discoverable *only* through the parent's link, and that link exists only in a buffer that is then backgrounded; a `:q!` or a crash orphans it. Under `'nohidden'` the user gets a raw Lua traceback on the key README and `<C-g>?` now advertise as primary, and no navigation.

Fix sketch: the prune path already solved this — `M.cmd.ChatPrune` does `vim.cmd("write")` on the parent before opening the child (`init.lua:3616`). Do the same in `insert_plain` before the scheduled `:edit`, and pin it with a test asserting the parent's on-disk content contains the `🌿:` line after `.n()`.

## 3. Important findings

- **`init.lua:2513-2519` — BR-4 fixed the chat call site and left the markdown one.** `branch_inserters(...).i` is `function() vim.cmd("stopinsert"); insert_plain() end`; the markdown dispatch re-implements that byte-for-byte as `i = function() vim.cmd("stopinsert"); md_branch.n() end`. Pass `md_branch` directly, as the chat site now does. (ARCH-DRY)
- **`init.lua:4564` and four siblings — BR-5's class was not swept.** `format_branch_ref` now delegates, but the identical `branch_prefix .. " " .. path .. ": " .. topic` shape survives at `init.lua:3066, 3600, 3613, 3671, 4564` — and `:4564` is a line **this commit edited**. Measured class width is 6 sites, not the 3 BR-5 named. The requested guard row in `tests/arch/single_source_sweeps_spec.lua` (whose own preamble says "a sweep without a guard is a snapshot") was not added. (ARCH-DRY, ARCH-PURPOSE)
- **`atlas/traceability.yaml:141-150` — BR-2's routing half is untouched.** `scripts/spec_test_map.sh list-tests chat/inline_branch_links` returns `tree_export_spec`, `inline_branch_spec`, `parse_chat_spec` — neither new spec, and `lua/parley/branch_ref.lua` is not in the `code:` list. `make test-changed` on a change to the new module runs nothing, in the same commit that changed `atlas/chat/inline_branch_links.md`.
- **Fixes that survive their own revert (rule finding, 4th+ in `test-does-not-pin-the-fix`).** Of the code-touching fixes in `8ade807`, three go green on revert with the full suite passing: BR-10's `parent_ref` fallback (no fixture has a non-chat parent, so the `or` branch is never entered), BR-11's `chat_toggle_tool_folds = M.cmd.ToggleToolFolds` (restoring the inline closure leaves both specs at 26/30 green), BR-17's `_parley_bufs` guard (works live — I confirmed foldenable is untouched in a scratch buffer — but no test enters it). BR-18 shipped a seam no test uses. Don't patch these four one at a time: adopt the rule that a milestone-review fix lands with its revert demonstrated, and the closing commit's `## Log` names, per finding id, the test that goes red without it — any finding for which that line cannot be written is disposed `deferred`, not `addressed`.
- **`init.lua:4545` — selection text reaches a `gsub` replacement unescaped.** `template:gsub("topic: %?", "topic: " .. topic)` with `topic = 'what is "50% off"'` raises `invalid use of '%' in replacement string`. Pre-existing on the visual path, but `<M-i>` is now the advertised primary key and `branch_ref.topic_for_selection` is a new "PURE" helper whose spec doesn't cover it. Use a function replacement or escape `%` → `%%`. (ARCH-SECURE)
- **`8ade807` committed nvim runtime state into the tree.** `.local/share/nvim/parley/persisted/state.json`, `.local/state/nvim/log`, `.local/state/nvim/parley.nvim.log` (203 lines, incl. a full provider-config dump with `secret = "parley-local"` and absolute user paths), `.local/state/nvim/shada/main.shada`. `Library/` and `nvim.xianxu/` from the same 08:34 manual run survive untracked only because they are empty. API keys are redacted, so no live credential leaked. `.gitignore` has no `.local/` entry, so this recurs on the next manual run — and its own trailing comment records that #205 already hit this class once. (ARCH-SECURE)
- **The changed-key doc sweep stopped at README (2nd in `readme-missing-for-changed-surface`).** `atlas/chat/lifecycle.md:12` still titles its section "Branching / Pruning (`<C-g>b`)" and `atlas/chat/format.md:16` still says "`<C-g>i` inserts link" — both now legacy aliases, in a commit that edited three other atlas files. Rule, not instance: when a shipped key changes, the deliverable is the enumeration `grep -rn '<old-key>' README.md ARCH.md atlas/ docs/ lua/` swept in the same commit, plus a guard row in `tests/arch/single_source_sweeps_spec.lua` asserting no doc names a key that is not `resolve_keys(entry, config)[1]` — the file already has a precedent row ("picker keys come from the keybinding registry, not literals").

## 4. Minor findings

- `keybinding_registry.lua:478` duplicates `config.lua:362`'s chord list with nothing asserting the two agree — a dormant second source, and the artifact M2's superset guard will compare against (ARCH-DRY).
- `keybindings_spec.lua:331` `dofile("lua/parley/config.lua")` is CWD-relative; it only works because every runner `cd`s to the repo root.
- `branch_ref_spec.lua` still has no case for a selection containing `](` or `)`, which breaks the emitted markdown link — BR-2 named it and the new spec skipped it.
- `docs/parley.nvim.md.parley-backup.1` is tracked despite `.gitignore`'s `*.parley-backup.*` (pre-existing, same hygiene class as the `.local/` finding).

## 5. Test coverage notes

11 new/changed assertions, all green, and I verified four of them go red on revert (BR-1 topic, BR-3 shipped list, BR-12 key order, and the prune list). The gap is uniform and named above: the fixes with no revert-demonstration are exactly the ones with no test. Two specific holes worth closing with the Critical: nothing drives `.i()` at all, and nothing drains the scheduled `:edit`, so `branch_child_spec` asserts on state captured *before* the navigation half of `insert_plain` runs.

## 6. Architectural notes

- **ARCH-DRY — flag.** Two consolidations stopped at the instance: the markdown `.i` wrapper and five surviving formatter restatements.
- **ARCH-PURE — pass.** `branch_ref.lua` is pure and tested without IO; the IO stays in `branch_inserters`.
- **ARCH-PURPOSE — flag.** M1's stated purpose is "extract one helper both buffer types call, *so the pair cannot drift again*". The helper exists; the guard against drift does not (no arch row, no traceability entry, one call site still hand-rolling). The purpose is the guard, not the extraction.
- **ARCH-MOCK — pass.** No new external binary or service; the new integration spec uses a real temp dir, which is the right seam here.
- **ARCH-CONSTRAINTS — pass.** `insert_plain` does one small `writefile` plus a template render on the keystroke path; bounded and cheap.
- **ARCH-SECURE — flag.** Unescaped selection text into a Lua pattern replacement; runtime state with user paths and a provider-config dump committed.
- **ARCH-ORDER — flag.** `writefile(child) → mutate parent buffer → schedule(edit + startinsert!)` is a three-effect sequence with no rollback, no durable commit of effect two, and no seam that lets a test observe or inject the interleaving. This is the Critical and BR-18 seen from the same angle.

For M2: the disable direction (`shortcut = ""`) and the superset guard both hinge on `resolve_keys` reading a `default_key` that now duplicates `config.lua`. Decide which artifact the guard treats as the source before writing it, or the guard will certify the duplication rather than the contract.

## 7. Plan revision recommendations

- `## Revisions` entry on M1 row 2 ("unify the branch paths"): the row is delivered for the chat dispatch only; the markdown dispatch still re-implements `.i`, and the anti-drift guard the row's rationale promises (traceability entry + arch sweep row) is not present. Either narrow the row's claim or carry the guard into the same milestone.
- `## Revisions` entry recording the branch-path durability decision: the M1 row that chose "create immediately … and **open** the child" did not settle whether the parent is written. It must be, or the milestone ships an on-disk-inconsistent tree by design. Name it in the row so M2 does not re-derive it.
- `## Log`: the entry claims "Suite green (195 files)". Measured at `8ade807`: green, with lint reporting 351 files. Not a defect, but the number in the Log is not the number the toolchain prints.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Verified by revert: "?" -> "" turns branch_child_spec:78 red while the three create_child_chat tests stay green.
  - id: BR-2
    disposition: not-addressed
    note: |
      Tests added, but atlas/traceability.yaml:141-150 is untouched; list-tests chat/inline_branch_links returns neither new spec and omits branch_ref.lua.
  - id: BR-3
    disposition: addressed
    note: |
      Verified by revert: deleting chat_shortcut_branch_ref from config.lua turns "config.lua itself ships both chord lists" red.
  - id: BR-4
    disposition: not-addressed
    note: |
      Chat site fixed; init.lua:2513-2519 still re-implements .i verbatim as stopinsert + md_branch.n().
  - id: BR-5
    disposition: not-addressed
    note: |
      format_branch_ref delegates, but 5 inline restatements remain (init.lua:3066,3600,3613,3671,4564 - the last edited by this commit) and no arch sweep row was added.
  - id: BR-6
    disposition: addressed
    note: |
      README:156,168 now lead with <M-p>/<M-i> and describe the create-and-open behavior.
  - id: BR-7
    disposition: addressed
    note: |
      Re-measured all six config shapes against resolve_keys; the atlas table and the registry comment both match.
  - id: BR-8
    disposition: addressed
    note: |
      grep -rn superset atlas/ lua/ tests/ returns nothing.
  - id: BR-9
    disposition: addressed
    note: |
      Plan changed: the M2 resolve_keys row now names BR-9 and owns both shrink and disable directions.
  - id: BR-10
    disposition: not-addressed
    note: |
      Code present but unreachable in every fixture - reverting to plain basename leaves the suite green; heuristic is filename-shape, so a timestamp-named md outside a chat root still gets an unresolvable ref.
  - id: BR-11
    disposition: not-addressed
    note: |
      Verified by revert: restoring the inline closure leaves config_tools_spec 26/26 and keybindings_spec 30/30 green. The added assertion checks the registry entry exists, not the identity the title claims.
  - id: BR-12
    disposition: addressed
    note: |
      Verified by revert: reordering the shipped list to <C-g>i-first turns three tests red.
  - id: BR-13
    disposition: addressed
  - id: BR-14
    disposition: addressed
  - id: BR-15
    disposition: not-addressed
    note: |
      Atlas citations removed, but the same commit added two new wrong ones - init.lua:2087 cites 2812-2816 for the glob fallback (that is _resolve_chat_path_candidates; the fallback is 2840-2856) and :2112 cites 2652 for the slug topic guard (that is the file_path=="" guard; the topic guard is 2670).
  - id: BR-16
    disposition: addressed
  - id: BR-17
    disposition: not-addressed
    note: |
      Guard works live (confirmed: foldenable untouched in a scratch buffer, warning emitted) but no test enters it; reverting it leaves the suite green.
  - id: BR-18
    disposition: not-addressed
    note: |
      M._branch_inserters lets a test CALL the inserter, not observe ordering. No test invokes .i(), nothing drains the scheduled edit+startinsert!, and the seam's own comment attributes it to BR-1.
findings:
  - id: new
    severity: Critical
    family: partial-effect-not-committed
    title: |
      Branch writes the child to disk, leaves the parent's link unsaved, then navigates away - and throws a raw E37 traceback under 'nohidden'
    detail: |
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
  - id: new
    severity: Important
    family: test-does-not-pin-the-fix
    title: |
      Three of this round's fixes survive their own revert with the full suite green
    detail: |
      This is the 4th finding in family test-does-not-pin-the-fix. Earlier rounds fixed
      instances. Do not fix these instances - fix the rule. Measured prevalence this
      round: BR-10 (parent_ref fallback, no fixture enters the branch), BR-11 (tool-fold
      identity, inline closure restores green), BR-17 (buffer-scope guard, no test enters
      it) all revert clean; BR-18 shipped a seam no test uses. Rule: a milestone-review
      fix lands with its revert demonstrated, and the closing commit's Log names, per
      finding id, the test that goes red without it. A finding for which that line cannot
      be written is disposed deferred, not addressed.
  - id: new
    severity: Important
    family: user-text-unescaped-in-lua-pattern
    title: |
      Selection text reaches a gsub replacement unescaped, so branching on a selection containing % throws
    detail: |
      init.lua:4545 does template:gsub("topic: %?", "topic: " .. topic). Confirmed in Lua:
      topic = 'what is "50% off"' raises "invalid use of '%' in replacement string", and a
      topic containing %1 silently substitutes the capture. Pre-existing on the visual
      path, but M1 promoted <M-i> to the advertised primary key and added
      branch_ref.topic_for_selection as a PURE helper whose spec has no such case. Use a
      function replacement, or escape % -> %%. ARCH-SECURE.
  - id: new
    severity: Important
    family: scratch-artifact-swept-into-commit
    title: |
      8ade807 committed nvim runtime state (state.json, two logs, shada) and .local/ is still not gitignored
    detail: |
      The commit added .local/share/nvim/parley/persisted/state.json, .local/state/nvim/log,
      .local/state/nvim/parley.nvim.log (203 lines including a full provider-config dump
      with secret = "parley-local" and absolute user paths) and
      .local/state/nvim/shada/main.shada. Library/ and nvim.xianxu/ from the same 08:34
      manual run survive untracked only because they are empty. API keys are redacted, so
      no live credential leaked. .gitignore has no .local/ entry, so the next manual nvim
      run in the repo root reproduces it - and the file's own trailing comment records
      that #205 already hit this class. ARCH-SECURE.
  - id: new
    severity: Important
    family: readme-missing-for-changed-surface
    title: |
      The changed-key doc sweep stopped at README; two atlas files still name the superseded primaries
    detail: |
      This is the 2nd finding in family readme-missing-for-changed-surface. Earlier rounds
      fixed instances. Do not fix this instance - fix the rule. Surviving instances:
      atlas/chat/lifecycle.md:12 "Branching / Pruning (<C-g>b)" and atlas/chat/format.md:16
      "<C-g>i inserts link", in a commit that edited three other atlas files. Rule: when a
      shipped key changes, the deliverable is the enumeration
      grep -rn '<old-key>' README.md ARCH.md atlas/ docs/ lua/ swept in the same commit,
      plus a guard row in tests/arch/single_source_sweeps_spec.lua asserting no doc names a
      key that is not resolve_keys(entry, config)[1]. That file already has the precedent
      row "picker keys come from the keybinding registry, not literals".
  - id: new
    severity: Minor
    family: duplicate-helper-not-retired
    title: |
      keybinding_registry.lua:478 duplicates config.lua:362's chord list with nothing asserting they agree
    detail: |
      Dormant today (resolve_keys prefers config), but it is the artifact M2's superset
      guard will compare against, so the two must be reconciled before that guard is
      written or it certifies the duplication rather than the contract.
  - id: new
    severity: Minor
    family: test-harness-assumption
    title: |
      keybindings_spec.lua:331 dofile("lua/parley/config.lua") is CWD-relative
    detail: |
      Works only because every runner cd's to the repo root. Resolve against a path
      derived from the spec's own location.
  - id: new
    severity: Minor
    family: pure-extraction-without-tests
    title: |
      branch_ref_spec has no case for a selection containing "](", which breaks the emitted markdown link
```

---

## Re-review — 2026-09-06T09:31:47-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 54a5c7a2ecaa3faf268d867f5222e73bd6f1dafb..f617b96c9416e49c2a7be91b8fd3df4a2a9a34ed |
| command | sdlc milestone-close --issue 214 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-06T09:31:47-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The consolidation itself is good work — `branch_ref.lua` is genuinely pure, the seven hand-built `🌿:` lines really are routed through one formatter, and I confirmed the new arch guard fires by planting a re-inline in `highlighter.lua` (goes red). The suite is green (351 files, luacheck clean, every spec PASS). What blocks SHIP is that this round's own claimed fixes do not hold under the test that BR-20 demanded and that the closing commit says it now applies: I reverted five of them in a scratch copy of the tree and the suite stayed green each time — including **BR-19, the Critical data-loss fix introduced this round**. Worse, BR-19 was fixed at the site, not the class: `insert_inline` (the `v` mode of the same advertised `<M-i>`) still writes the child to disk and leaves the parent's link unsaved with no write at all — I reproduced it in a real buffer. Two user-facing docs shipped this round assert behavior the code does not have (README says the visual path opens the child; it does not), the markdown branch path now silently `:write`s the user's arbitrary document (persisting unrelated unsaved edits — reproduced), and three new `init.lua:NNNN` citations were wrong the moment they were committed.

## 1. Strengths

- **BR-5's guard is real, not decorative.** `tests/arch/single_source_sweeps_spec.lua:382` — I planted `branch_prefix .. " " .. parsed.path .. ": "` back into `highlighter.lua:725` in a scratch clone with a live git index and the guard went red. That is the one fix this round that survives its own revert.
- **`branch_ref.lua` is genuinely PURE** (ARCH-PURE pass): `tests/unit/branch_ref_spec.lua` runs with no filesystem, no `vim.fn`, no mocks. The extraction earned its docstring claim.
- **BR-3/BR-12 are properly closed.** `keybindings_spec.lua:350` reads the *shipped* `config.lua` via `dofile`, not the merged table, and the chord assertions compare the full key **list** — an assertion on `keys[1]` would have stayed green while an alias vanished, which is exactly the shrink class PQ-1 named.
- **`.gitignore:49-53`** records *why* the entry exists and how the artifact got in, which is the form that survives the next reader.
- **The atlas Resolution table** (`atlas/ui/keybindings.md:33-45`) matched the code when I checked each row against `resolve_keys` — measured, as claimed.

## 2. Critical findings

None that I can pin as a crash or silent corruption on the primary path beyond what is already carried as Important below. The `insert_inline` residue (finding 3.3) is the same *shape* as BR-19 but with materially smaller blast radius: focus stays in the parent, so Vim's own unsaved-buffer guard applies and only `:q!`/crash loses the link.

## 3. Important findings

**I3-1 — `README.md:172` documents behavior the visual path does not have.**
> "**Either way it creates the child chat and opens it**, so the question is typed in the child."

`insert_inline` (`init.lua:2144-2166`) creates the child and returns; there is no `edit`, no `vim.schedule`. I ran it against a real chat buffer: the current buffer afterwards is still the parent. Only the no-selection path opens.

*This is the 3rd finding in family `docs-assert-unverified-behavior`.* Earlier rounds fixed instances (BR-7, BR-8). Do NOT fix this instance — the rule is: **a sentence in README/atlas that asserts a runtime effect ("creates", "opens", "writes", "renames") lands with a test naming that effect, or it is written as the narrower claim the code supports.** The enumerable sweep this round is small — `grep -nE '\*\*(Either|Both|Always|Never)' README.md atlas/` plus every clause added by this range — and the missing guard is the one the family keeps asking for: a spec that reads the atlas/README claim and exercises it. `atlas/chat/inline_branch_links.md:12-18` is the counter-example done right; it describes visual and normal separately and is correct.

**I3-2 — the markdown branch key now writes the user's document to disk, persisting unrelated unsaved edits.** `init.lua:2126-2134`, reached from `setup_markdown_keymaps` via `md_branch.n`. Reproduced:

```
modified before: true
modified after:  false
on-disk now:
  | # Notes
  | 🌿: 2026-09-06.09-29-32.294.md:
  | UNSAVED USER EDIT     <-- the user never asked for this to be saved
```

Before this round the markdown n-path inserted a line and started insert mode; it did not write. `:write` commits the *whole buffer*, not the ref line, so a user mid-edit in a spec/README who presses `<M-i>` has their pending edits persisted and is then navigated away from the document. No doc mentions it and no test covers it. Family: `effect-wider-than-declared-action` (new). Fix sketch: keep the durability guarantee but scope it — write only when `buf` is a parley-owned chat (`M._parley_bufs[buf] == "chat"`), and on a foreign markdown buffer either skip navigation (stay put, leave the line unsaved as before) or prompt. Whichever you choose, say it in README and pin it with a spec asserting `vim.bo[buf].modified` for the markdown case.

**I3-3 — BR-19's ordering fix landed on `insert_plain` only; `insert_inline` still leaves the parent's link unsaved.** `init.lua:2144-2166` has no `write`. Reproduced against a real chat buffer: after `.v()`, the child is on disk with a back-link and `vim.bo[buf].modified == true` on the parent. The child is discoverable *only* through the link that was never written.

*This is the 2nd finding in family `partial-effect-not-committed`.* Do NOT fix this instance. The rule: **when a keypress produces a durable external artifact (a file on disk) plus an in-buffer reference to it, every mode of that keypress commits the reference in the same action; the enumeration is the returned dispatch table's keys.** For `branch_inserters` that is exactly `{n, i, v}` — three rows, one of which was swept. Write the enumeration into the code (one commit helper both `insert_plain` and `insert_inline` call before returning) and pin it with a spec that iterates the dispatch table rather than naming a mode.

**I3-4 — BR-20's rule was restated at the wrong granularity, and five of this round's fixes revert clean.** The commit body offers per-*file* revert counts ("branch_ref 3 red, chat_finder 1, config 5, highlighter 1, init 4, keybinding_registry 3"). BR-20 asked for per-*finding* pinning. Reverting a whole file tells you the file is covered by something; it says nothing about whether the finding's fix is covered. Measured this round, each reverted in isolation with the relevant specs run:

| finding | fix reverted | suite result |
|---|---|---|
| BR-19 | drop the `ok_write` write-before-navigate block | green (4/4) |
| BR-21 | `gsub(..., function() … end)` → string concat | green (9/9 + 4/4) |
| BR-11 | `= M.cmd.ToggleToolFolds` → inline closure | green (26/26, 30/30, 30/30) |
| BR-10 | `parent_ref` fallback → always basename | green (4/4) |
| BR-17 | (no test invokes `ToggleToolFolds` at all) | n/a — unreachable by the suite |

BR-21 is the instructive one: two tests *were* written for it, and they re-implement the production `gsub` inside the test body rather than calling `create_child_chat`. They assert that the fix's mental model is self-consistent, not that the call site uses it. That is the exact trap the gate's own checklist names.

**I3-5 — BR-23's rule half was not delivered.** The two atlas instances are swept (verified: `grep -rn '<C-g>b\|<C-g>i' README.md ARCH.md atlas/ docs/ lua/` now returns only alias mentions). The rule asked for a guard row in `single_source_sweeps_spec.lua` asserting no doc names a key that is not `resolve_keys(entry, config)[1]`; the row that landed is about the branch-ref formatter instead.

*This is the 3rd finding in family `readme-missing-for-changed-surface`.* Note the rule as stated needs one refinement before it can be written: README/atlas legitimately name aliases ("`<M-p>` (or `<C-g>b`)"), so the guard must assert *the first key named is `keys[1]`*, not that no other key appears.

**I3-6 — `atlas/traceability.yaml:141-150` still lists only the four old files.** `lua/parley/branch_ref.lua`, `tests/unit/branch_ref_spec.lua` and `tests/integration/branch_child_spec.lua` are absent, so `make test-changed` routes an edit to the new module nowhere. This is the second half of BR-2 and is a one-line-per-entry fix.

## 4. Minor findings

- `init.lua:2082` — the `branch_inserters` docstring says the child "is created **with an empty topic** and OPENED", contradicting the `"?"` sentinel the body passes 25 lines below and the BR-1 fix's own inline comment. *3rd in family `stale-comment-after-move`* — rule: when a fix changes a literal value, the same commit greps that value's prose description (`grep -rn 'empty topic' lua/ atlas/ README.md`) before closing the finding.
- `init.lua:2087`, `:2112`, `:2125` — three new volatile citations, all wrong at commit time: `init.lua:2812-2816` is `sync_moved_chat_buffers`, not the glob fallback (which is `:2856-2875`); `init.lua:2652` is not the slug rename (`:2678`); `init.lua:3617` is not ChatPrune's parent write (`:3634`). Only `chat_respond.lua:1934` is accurate. *2nd in family `volatile-line-citations-in-docs`* — rule: cite a **symbol name**, not a line number (`resolve_chat_path`'s fuzzy fallback, `M.cmd.ChatPrune`'s parent write); a symbol name survives every edit above it and is greppable.
- `tests/arch/single_source_sweeps_spec.lua:388` — the guard matches the literal string `branch_prefix .. " " ..`. A copy written with any other variable name, or `..' '..`, passes. Broaden to a pattern on the prefix value or on `": "` concatenation near a `.md` path.
- `lua/parley/keybinding_registry.lua:478` — the new `default_key` list is a byte-identical duplicate of `config.lua:362` with nothing asserting they agree (BR-24, still open; it is the artifact M2's superset guard will compare against).
- `tests/unit/keybindings_spec.lua:350` — `dofile("lua/parley/config.lua")` is still CWD-relative (BR-25).
- `M.cmd.ToggleToolFolds` warns "Tool folds apply to parley chat buffers **only**" but `M._parley_bufs[buf]` is also `"markdown"`, so markdown buffers pass the guard. Message and guard disagree.
- `branch_ref_spec` has no case for a selection containing `](` (BR-26), nor for a selection ending in a multibyte character — `getpos("'>")` returns the first byte of the last char under `selection=inclusive`, so `line:sub(start_col, end_col)` truncates it mid-codepoint. Both are cheap now that the function is pure.

## 5. Test coverage notes

The suite is green and the two new specs are real tests, not mock theatre — `branch_child_spec` deliberately drives the *call site* (`_branch_inserters(buf,false).n()`) because BR-1 lived there, which is the right instinct and correctly closes BR-18. The gap is that this instinct was applied to exactly one finding. What is untested after this round: the parent write (BR-19), the `%`-in-topic path through `create_child_chat` (BR-21), the command/callback identity (BR-11), the non-parley-buffer guard (BR-17 — `ToggleToolFolds` is never invoked by any spec), the markdown parent fallback (BR-10), and the entire `i` and `v` modes of the dispatch table. Also note `branch_child_spec.lua:84` leaves an unflushed `vim.schedule(edit + startinsert!)` in the scheduler while `after_each` deletes the tmpdir — harmless today because it is the file's last test, but it is a latent flake and it means the navigation half of BR-19 is not merely unasserted, it is unobserved.

## 6. Architectural notes

- **ARCH-DRY — flag.** `init.lua:2530-2534` still rebuilds the `i` wrapper (`stopinsert` + `md_branch.n()`) that `branch_inserters` already returns, leaving `.i` dead at zero call sites on the markdown side. BR-4 fixed the chat site and left its twin — the same site-not-class shape the commit message says it was correcting elsewhere. Pass `md_branch` directly.
- **ARCH-PURE — pass.** Clean pure/IO split in `branch_ref.lua`; the IO half stays in `branch_inserters`.
- **ARCH-PURPOSE — flag.** Two shadow-sweeps came up short: BR-19 swept `n`/`i` and not `v` (I3-3), BR-4 swept chat and not markdown. The consolidation's stated purpose — "so the pair cannot drift again" — is not met while one of the two call sites still re-implements a mode.
- **ARCH-MOCK — pass.** No new external binary or service dependency. The arch guard shells to `git ls-files`, consistent with the existing guards in that file.
- **ARCH-CONSTRAINTS — flag (minor).** `<M-i>` is a keystroke path and now performs two synchronous disk writes (`create_child_chat`'s `writefile`, then the parent `:write`) plus a buffer reload, with no budget stated. Chat files are small so this is likely fine, but it is an unbudgeted change on the interaction path the plan itself calls "what gets *felt*."
- **ARCH-SECURE — pass with residue.** The `%`-in-replacement fix is correct (`init.lua:4561`) and `fnameescape` is used on the navigation path; `.local/` is ignored and the runtime state is out of HEAD. Residue: the `8ade807` blobs (including `secret = "parley-local"` and absolute user paths) remain reachable in the branch history and will land on `main` unless the branch is squashed or rebased. *2nd in family `scratch-artifact-swept-into-commit`* — rule: a scratch artifact swept into a commit is not remediated by deleting it in a later commit on the same branch; the branch must not carry the blob to `main`.
- **ARCH-ORDER — flag.** The `(state, event)` enumeration for this component is literally the returned dispatch table `{n, i, v}`, and the write-ordering transition was written for one of the three rows. Separately, the error path (`ok_write == false`) unwinds the sequencing but drops the in-flight effect: the child file is already on disk with a back-link and is not removed. And the `vim.schedule(edit → normal! G → startinsert!)` chain still has no injectable seam, so no test can observe or reproduce an ordering failure in it.

## 7. Plan revision recommendations

- **`workshop/issues/000214-curate-default-keybindings.md`, `## Revisions`:** the M1 row "unify the branch paths … Extract one helper both buffer types call, so the pair cannot drift again" is checked `[x]`, but the markdown call site still re-implements `.i` and the two paths still diverge on parent-commit. Either uncheck it or narrow its wording to what shipped.
- **Same file, `## Revisions`:** record that `branch_inserters` writes the parent buffer before navigating, and that this applies to *arbitrary markdown buffers* as well as chat files — that is a user-visible policy decision (whose file parley is willing to save) that no artifact currently states.
- **Add a `## Core concepts` table to the issue's Plan.** The two arch guards in `single_source_sweeps_spec.lua:61` and `:135` are hardwired to `000205-*`, so #214 added a module, two specs and a command with no table-vs-code cross-check at all. Parameterising those guards on the issue id would close this for every issue at once, and is the kind of one-line generalisation §6 asks for.
- **`## Log`:** BR-20's rule needs restating at per-finding granularity before the next round, with the closing commit naming, per finding id, the test that goes red without the fix. The per-file revert table that replaced it cannot detect any of the five cases measured above.

---

## Re-review — 2026-09-06T09:55:45-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 54a5c7a2ecaa3faf268d867f5222e73bd6f1dafb..1d7ae62017a0356eb9dd1aa333f42cd5abb0ad47 |
| command | sdlc milestone-close --issue 214 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-06T09:55:45-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Round 3's own two fixes are the best work in this range: `commit_reference()` is a real enumeration over the dispatch table, and I confirmed it by mutation in a git clone — removing the plain-path commit, removing the inline commit, or removing the scope guard each turns `branch_child_spec` red while the rest of the suite (351 files, lint clean) stays green. What blocks SHIP is that the scope guard fixed I3-2 by adding an early return that nobody traced through the *markdown* path: pressing `<M-i>` in an ordinary markdown file now inserts the ref line, writes a child chat to disk, and then returns — no cursor move, no `startinsert`, no navigation, no save. I measured base vs HEAD through the real keymap: base left the cursor at `{3,34}` with `startinsert!` queued and created **no** file; HEAD leaves the cursor at `{2,0}` in normal mode and leaves a stray chat file in `chat_dir` referenced only by an unsaved line. The code comment claims this "keeps the pre-#214 behaviour"; it does not. Separately, BR-20's rule is still not in force — I reverted BR-10, BR-11, BR-17 and BR-21 one at a time and the **full suite stayed green for all four**, which is the fourth round in a row that this family has reported the same thing.

## 1. Strengths

- **BR-19 is genuinely closed, and pinned.** `tests/integration/branch_child_spec.lua:130-149` iterates `pairs(inserters)` and asserts the table is exactly `{i,n,v}`, so a new mode without coverage fails. Verified by three separate mutations in a scratch clone; each one goes red.
- **The scope guard is real and reachable.** `M._parley_bufs[buf] = "chat"` is set in `highlighter.lua:1063` on `BufEnter` before `prep_chat` wires the keymaps, so the guard fires in production, not just in fixtures. Removing it turns `does NOT write a foreign markdown buffer` red.
- **BR-5 is fully swept.** Every full-line `🌿:` construction in `lua/` now routes through `branch_ref.format_ref_line` (`init.lua:2066,2130,3104,3638,3651,3709,4606`, `chat_finder.lua:765`, `highlighter.lua:725`), and `tests/arch/single_source_sweeps_spec.lua:378` guards it.
- **`branch_ref.lua` is genuinely PURE** — `tests/unit/branch_ref_spec.lua` runs 9 assertions with no filesystem, no `vim.fn`, no mocks. ARCH-PURE pass.
- **BR-15 is clean.** No `.lua:NNNN` citation survives in `atlas/` from this range, and the one line citation added to code (`chat_respond.lua:1934`) is accurate — I checked it.

## 2. Critical findings

**`lua/parley/init.lua:2109-2118` + `:2151` — the markdown normal/insert branch path lost its cursor move and `startinsert`, silently.**

Measured through the real keymap in a clone at each end of the window:

```
base 54a5c7a2:  cursor {3,34}, startinsert! queued, chat_dir = {}          (no child)
HEAD 1d7ae62:   cursor {2, 0}, normal mode,        chat_dir = {…189.md}    (child created)
```

`commit_reference()` returns `false` on any buffer that is not `"chat"`, and `insert_plain` treats that as "do not navigate" and returns — but the pre-#214 markdown path did not navigate either; it moved the cursor onto the new ref line and scheduled `startinsert!` so the user could type the topic (`git show 54a5c7a2:lua/parley/init.lua`, `md_insert_branch_ref`). That step has no home in the unified helper, so it was dropped for the buffer type that used it. The user presses the key parley now advertises as primary and sees nothing happen. Fix sketch: put the non-chat fallback in `insert_plain` explicitly — `nvim_win_set_cursor(0, {cursor_pos[1]+1, 0})` + `vim.schedule(startinsert!)` when `committed` is false — and pin it with a spec asserting cursor row and `mode()` for the markdown case, so the two buffer types' *observable effects* are enumerated the way the modes now are.

## 3. Important findings

**`lua/parley/init.lua:2142-2151` — on a markdown buffer the branch key creates a durable child on disk and leaves the only reference to it unsaved, with no navigation.**

*This is the 2nd finding in family `partial-effect-not-committed`.* Do NOT fix this instance. The rule round 3 wrote — "every mode of that keypress commits the reference in the same action, and the enumeration is the dispatch table's keys" — was enumerated over the wrong axis. The dispatch table has three keys; the *component* has two buffer types, and the fix swept modes and left `markdown` as an unnamed third state where the artifact is created and the reference is not committed. The rule needs restating as: **the enumeration is `modes × buffer types`, and every cell either commits the reference or does not create the artifact.** The cheap resolution for the `markdown` cell is the second half — do not call `create_child_chat` when the reference cannot be committed — which also restores the pre-#214 contract the comment claims. Reproduced above: `chat_dir = {2026-09-06.09-53-24.189.md}` with `modified = true` and the ref line only in the buffer.

**`atlas/chat/inline_branch_links.md:6-19` asserts two things the code does not do.**

"Chat and markdown buffers differ **only** in the link target" and "**Normal / insert mode**: … creates the child, and **opens it**". Both are false for markdown at HEAD: it also differs on parent-commit and on navigation, and markdown never opens the child. The atlas also never mentions that branching now `:write`s the parent buffer — a user-visible policy (whose file parley is willing to save) that no artifact states. README is correctly scoped (`**In Chat Buffer**`) and is fine.

*This is the 3rd finding in family `docs-assert-unverified-behavior`.* Do NOT fix this instance. Round 3 stated the rule ("a sentence in README/atlas that asserts a runtime effect lands with a test naming that effect") and then broke it in the same commit that applied it to README — which is the signal that the rule needs a mechanism, not another restatement. Measured prevalence: BR-7, BR-8, I3-1, this. The missing mechanism the family keeps asking for is a spec that reads the atlas/README claim and exercises it; absent that, the enforceable substitute is the enumeration `git diff --name-only <base> HEAD -- atlas/ README.md` swept against every effect verb ("creates", "opens", "writes", "saves", "renames", "only") added in the same range, run before the closing commit.

**`workshop/issues/000214-curate-default-keybindings.md:341-372` — the Plan still states three superseded decisions and has no `## Revisions` section.**

Row 1 names `global_shortcut_branch_ref` (code ships `chat_shortcut_branch_ref`) and the order `{ "<M-S-CR>", "<M-i>", "<C-g>i" }` (code ships `<M-i>` first). Row 3 says "create immediately with an **empty topic**" (code ships `"?"`, which was BR-1's fix). Row 2 is `[x]` on "Extract one helper both buffer types call, so the pair cannot drift again", while the markdown call site still re-implements `.i` and the two buffer types now diverge on three observable effects. AGENTS.md §1 requires an appended `## Revisions` entry rather than a stale row; two prior rounds recommended it and it has not been written. This is the artifact the close gate's plan-unchecked guard reads.

## 4. Minor findings

- `lua/parley/chat_finder.lua:777` still hand-builds `"[" .. branch_prefix .. topic .. "](" .. rel_path .. ")"`, the format `branch_ref.splice_inline_link` owns; the new arch guard only matches the full-line `branch_prefix .. " " ..` shape, so it does not see this. *This is the 4th finding in family `duplicate-helper-not-retired`* — do NOT fix the instance; the guard added at `single_source_sweeps_spec.lua:378` matches one literal concatenation idiom, which is why the sweep keeps missing siblings. The rule: the guard must key on the *emitted shape* (`"](" ` adjacent to a `.md` path, and `": "` after a prefix variable), not on one spelling of the concatenation.
- `lua/parley/init.lua:2114-2119` — `commit_reference` discards the `pcall` error, so a write failure reports "could not save the parent" with no cause; and `M.logger.info("Created branch to new chat: …")` at `:2148` now fires *before* the `committed` check, announcing success on the path where nothing was committed and nothing opened.
- `lua/parley/init.lua:1078-1082` — the warning reads "Tool folds apply to parley chat buffers **only**" but the guard is `if not M._parley_bufs[buf]`, which markdown buffers satisfy. Message and guard disagree.

## 5. Test coverage notes

Full suite green at HEAD (351 spec files, `make lint` 0/0). Mutation results, each reverted in isolation in a git clone with the whole suite re-run:

| fix | reverted | result |
|---|---|---|
| BR-19 plain-path commit | `commit_reference()` → `true` | **red** (branch_child_spec) |
| I3-3 inline commit | delete `commit_reference()` | **red** (branch_child_spec) |
| I3-2 scope guard | delete the `~= "chat"` early return | **red** (branch_child_spec) |
| BR-21 `%` escaping | `gsub(fn)` → string concat | green |
| BR-10 parent_ref fallback | → always basename | green |
| BR-11 callback identity | → inline closure | green |
| BR-17 buffer scope guard | delete the guard | green |

BR-21 is the instructive one and is unchanged from round 3's diagnosis: `branch_ref_spec.lua:53-67` re-implements the production `gsub` inside the test body instead of calling `create_child_chat`, so it asserts the fix's mental model, not the call site. A test at `branch_child_spec` passing `topic = 'what is "50% off"'` through `create_child_chat` and reading back the header would go red against the concat form.

Not covered after this round: the markdown branch path in any form (cursor, mode, navigation, orphan creation — the Critical above is entirely unobserved), the `%`-in-topic path through `create_child_chat`, the callback/command identity, the `ToggleToolFolds` buffer guard, and the markdown parent back-link fallback. `branch_child_spec.lua:130-149` also leaves two unflushed `vim.schedule(edit → G → startinsert!)` callbacks in the loop while `after_each` deletes the tmpdir — harmless today, latent flake, and it means the navigation half of BR-19 is unobserved rather than merely unasserted.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — flag.** `init.lua:2551-2557` still rebuilds the markdown `.i` wrapper that `branch_inserters` returns, so `.i` remains dead at zero call sites (BR-4, chat swept, markdown not). `chat_finder.lua:777` duplicates the inline-link format. `keybinding_registry.lua:478` duplicates `config.lua:362`'s key list with nothing asserting they agree (BR-24) — reconcile before M2's superset guard is written against it, or the guard certifies the duplication.
- **ARCH-PURE — pass.** Clean pure/IO split; the pure half is tested without IO, confirmed by running the spec.
- **ARCH-PURPOSE — flag.** Two shadow-sweeps came up short on the same axis: the durability rule enumerated modes and not buffer types (Critical + finding 3.2), and BR-4 swept the chat call site and not its twin. The consolidation's stated purpose — "so the pair cannot drift again" — is not met while one call site re-implements a mode and the two types diverge on three effects.
- **ARCH-MOCK — pass.** No new external binary or service; the arch guard shells to `git ls-files` consistently with the existing guards; tests run entirely inside the per-run scratch `HOME`/`TMPDIR`.
- **ARCH-CONSTRAINTS — flag (minor).** `<M-i>` is a keystroke path that now performs two synchronous disk writes (`writefile` for the child, then a full parent `:write`) plus a buffer reload, with no budget stated in the plan for the interaction the plan itself calls "what gets *felt*". Chat files are small so this is likely fine; state it rather than leave it implicit.
- **ARCH-SECURE — flag.** `.gitignore:49-53` landed and `1d7ae62`'s tree is clean, but `8ade807` still carries `.local/state/nvim/parley.nvim.log` (14 KB, including `secret = "parley-local"` and absolute user paths) plus three other runtime blobs; they reach `main` unless the branch is squashed or rebased. No live credential — API keys are redacted. Residue: `splice_inline_link` splices selected text into a markdown link unescaped, so a selection containing `](` emits a broken link (BR-26's missing case).
- **ARCH-ORDER — flag.** The `{n,i,v}` enumeration is now written down *and* pinned, which is real progress. Two gaps remain: the failure path still drops the in-flight effect — when `commit_reference` returns false the child is already on disk and is not removed, and with the markdown early-return that is now the *normal* path, not the exceptional one — and the `vim.schedule(edit → G → startinsert!)` chain still has no injectable seam, so no test can observe or reproduce an ordering failure in it (BR-18).

## 7. Plan revision recommendations

Append a `## Revisions` section to `workshop/issues/000214-curate-default-keybindings.md` (it has none; §1 requires appending, not overwriting):

1. **Config key name and order.** M1 row 1 says `global_shortcut_branch_ref = { "<M-S-CR>", "<M-i>", "<C-g>i" }`; the code ships `chat_shortcut_branch_ref = { "<M-i>", "<M-S-CR>", "<C-g>i" }`. The code is right on both counts (`chat_shortcut_*` is the prefix every `parley_buffer` entry uses; `## Log` records why `<M-i>` leads). Correct the row.
2. **Topic sentinel.** M1 row 3 says "create immediately with an **empty topic**"; BR-1 established that `"?"` is required, and the code ships it. Correct the row so the plan stops describing the bug.
3. **Row 2 scope.** "Extract one helper both buffer types call, so the pair cannot drift again" is `[x]`, but `.i` is still re-implemented at the markdown call site and the two types diverge on parent-commit, navigation, and cursor/insert. Either uncheck it or narrow the wording to what shipped.
4. **State the buffer-type policy.** Record explicitly what happens on a non-chat buffer: whether parley creates a child it cannot commit a reference to, and whether it saves the user's arbitrary document. That is a user-visible decision no artifact currently states, and it is the axis the Critical fell through.
5. **Add a `## Core concepts` table.** #214 added a module, two specs and a command with no table-vs-code cross-check; the two existing arch guards in `single_source_sweeps_spec.lua` are hardwired to `000205-*`. Parameterising them on the issue id closes this for every issue at once.

```findings
dispose:
  - id: BR-2
    disposition: not-addressed
    note: |
      Tests now exist (branch_ref_spec, 9 assertions, no IO); atlas/traceability.yaml:141-150 still lists only the four old files, so branch_ref.lua and both new specs route nowhere under make test-changed.
  - id: BR-4
    disposition: not-addressed
    note: |
      Chat site fixed (branch_ref = chat_branch); init.lua:2551-2557 still rebuilds n/i/v wrappers for markdown, so .i remains dead at zero call sites.
  - id: BR-5
    disposition: addressed
    note: |
      All full-line formatter sites route through branch_ref.format_ref_line; the arch guard at single_source_sweeps_spec.lua:378 is real.
  - id: BR-10
    disposition: not-addressed
    note: |
      Code fix is correct and reachable, but reverting parent_ref to the bare basename leaves the FULL suite green — measured in a git clone.
  - id: BR-11
    disposition: not-addressed
    note: |
      config_tools_spec.lua:436-447 still asserts only is_function plus registry-entry existence; reverting the callback to an inline closure leaves the full suite green — measured.
  - id: BR-15
    disposition: addressed
    note: |
      No .lua:NNNN citation from this range survives in atlas/; the one code citation added (chat_respond.lua:1934) is accurate — verified.
  - id: BR-17
    disposition: not-addressed
    note: |
      Guard added but no spec invokes ToggleToolFolds; deleting the guard leaves the full suite green — measured. Warning text says "chat buffers only" while markdown satisfies the guard.
  - id: BR-18
    disposition: not-addressed
    note: |
      M._branch_inserters seam exists and specs now drive it, but nothing observes the stopinsert -> schedule(edit/G/startinsert!) interleaving; branch_child_spec also leaves two unflushed schedules while after_each deletes the tmpdir.
  - id: BR-19
    disposition: addressed
    note: |
      Mutation-verified in a clone: removing the plain-path commit, the inline commit, or the scope guard each turns branch_child_spec red. The markdown residue is raised separately, not as BR-19.
  - id: BR-20
    disposition: not-addressed
    note: |
      Measured this round: BR-10, BR-11, BR-17 and BR-21 each revert clean with the full suite green; the issue's Log names no per-finding test.
  - id: BR-21
    disposition: not-addressed
    note: |
      init.lua:4586 uses a function replacement correctly, but branch_ref_spec.lua:53-67 re-implements the gsub in the test body; reverting to string concat leaves the full suite green — measured.
  - id: BR-22
    disposition: not-addressed
    note: |
      .gitignore entry landed and HEAD's tree is clean, but 8ade807 still carries the four blobs (14 KB log with secret = "parley-local" and absolute paths); they reach main unless the branch is squashed or rebased.
  - id: BR-23
    disposition: not-addressed
    note: |
      Both atlas instances swept, but the rule half was not delivered — no guard row asserts a doc names resolve_keys(entry, config)[1]; the row that landed guards the branch-ref formatter instead.
  - id: BR-24
    disposition: not-addressed
    note: |
      keybinding_registry.lua:478 still duplicates config.lua's list byte-for-byte with nothing asserting they agree.
  - id: BR-25
    disposition: not-addressed
    note: |
      keybindings_spec.lua:349 is still dofile("lua/parley/config.lua"), CWD-relative.
  - id: BR-26
    disposition: not-addressed
    note: |
      branch_ref_spec has no case for a selection containing "](" nor for one ending mid-codepoint.
findings:
  - id: new
    severity: Critical
    family: merged-path-loses-original-effect
    title: |
      Markdown normal/insert branch lost its cursor move and startinsert — the key now appears to do nothing
    detail: |
      commit_reference() returns false on any non-chat buffer and insert_plain
      treats that as "do not navigate" and returns, but the pre-#214 markdown
      path did not navigate either — it moved the cursor onto the new ref line
      and scheduled startinsert! so the user could type the topic. Measured
      through the real keymap: base 54a5c7a2 leaves cursor {3,34} with
      startinsert! queued and chat_dir empty; HEAD leaves cursor {2,0} in normal
      mode with a child file created. The code comment claims it "keeps the
      pre-#214 behaviour"; it does not. No test observes the markdown path.
  - id: new
    severity: Important
    family: partial-effect-not-committed
    title: |
      On a markdown buffer the branch key creates a child on disk whose only reference is never committed
    detail: |
      This is the 2nd finding in this family. Do not fix the instance. Round 3's
      rule enumerated the dispatch table's MODES; the component's state space is
      modes x buffer types, and the markdown cell creates the durable artifact
      while committing nothing and navigating nowhere — the exact BR-19 shape,
      relocated. Restate the rule as: every cell of modes x buffer types either
      commits the reference or does not create the artifact. For markdown the
      cheap resolution is the second half.
  - id: new
    severity: Important
    family: docs-assert-unverified-behavior
    title: |
      atlas/chat/inline_branch_links.md says markdown opens the child and that the two buffer types differ only in link target
    detail: |
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
  - id: new
    severity: Important
    family: plan-not-revised-after-decision-change
    title: |
      The issue Plan still states three superseded M1 decisions and has no Revisions section
    detail: |
      Row 1 names global_shortcut_branch_ref and the order {<M-S-CR>, <M-i>,
      <C-g>i}; the code ships chat_shortcut_branch_ref with <M-i> first. Row 3
      says "create immediately with an empty topic"; BR-1 established "?" and the
      code ships it. Row 2 is checked on "so the pair cannot drift again" while
      the markdown call site still re-implements .i and the two types diverge on
      three effects. AGENTS.md section 1 requires an appended "## Revisions"
      entry; the file has no such section, and this is the artifact the close
      gate's plan-unchecked guard reads.
  - id: new
    severity: Minor
    family: duplicate-helper-not-retired
    title: |
      chat_finder.lua:777 still hand-builds the inline branch-link format the new arch guard does not see
    detail: |
      This is the 4th finding in this family. Do not fix the instance. The guard
      at single_source_sweeps_spec.lua:378 matches one literal concatenation
      idiom (branch_prefix .. " " ..), which is why the sweep keeps missing
      siblings. The rule: key the guard on the emitted SHAPE — "](" adjacent to a
      .md path, and ": " after a prefix variable — not on one spelling of the
      concatenation.
  - id: new
    severity: Minor
    family: partial-effect-not-committed
    title: |
      commit_reference discards the write error, and the success log line fires before the committed check
    detail: |
      init.lua:2114-2119 pcalls the write and drops the error, so a failure
      reports "could not save the parent" with no cause. init.lua:2148 logs
      "Created branch to new chat: <file>" before the committed check, announcing
      success on the path where nothing was committed and nothing opened.
```

---

## Re-review — 2026-09-06T10:18:15-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 54a5c7a2ecaa3faf268d867f5222e73bd6f1dafb..db2f33140e561f3adbc4a81567bf6b94b9fb1b98 |
| command | sdlc milestone-close --issue 214 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-06T10:18:15-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Round 4's thesis — "stop patching, state the guarantee per buffer type" — is the right rule, and where it landed (the chat cells, the `n`/`i` markdown cell) it is well-implemented and pinned by a spec that iterates the dispatch table instead of naming a mode. But the rule was applied to two of the six `modes × buffer types` cells and skipped the third markdown cell: **`insert_inline` still calls `create_child_chat` on a foreign markdown buffer and then `commit_reference()` returns `false` without writing** (`init.lua:2199-2204`) — I reproduced it in a real buffer, and it leaves a child chat on disk whose only reference lives in an unsaved line. That is BR-28's exact shape, in the round that claims to have eliminated the class, and the atlas shipped this round (`atlas/chat/inline_branch_links.md:18`) now asserts the opposite as a contract. Separately, BR-20's rule ("a fix lands with its revert demonstrated") is still not adopted: I reverted four fixes in the working tree and the suite stayed green each time — BR-10, BR-11, BR-17 (the same three the last round measured) plus **BR-21, whose two new tests run the fixed `gsub` inside the test body rather than through `create_child_chat`**. Of 19 open findings, 3 are addressed and 16 are not.

## 1. Strengths

- **The guarantee block (`init.lua:2122-2135`) is the right abstraction and the chat cells honour it.** Stating ownership once, then branching on it, is the fix shape three earlier rounds were groping for.
- **`tests/integration/branch_child_spec.lua:141-152` enumerates the dispatch table rather than naming modes**, and asserts it is exactly `{i,n,v}` so a new mode without coverage fails. That is the anti-drift shape; it just needs the second axis.
- **BR-27 is genuinely pinned.** `branch_child_spec.lua:157-176` asserts the cursor lands on the new ref line for a foreign buffer; the early return that caused the Critical cannot come back silently.
- **`atlas/ui/keybindings.md:33-46` is accurate.** I re-read `resolve_keys` (`keybinding_registry.lua:959-999`) against all six rows of the table — including the non-obvious "bare string → `default_key`" and "`shortcut = \"\"` → `default_key`" rows. Measured, not inferred, and it matches.
- **BR-22 is fully closed.** `git ls-files | grep '^\.local'` is empty at HEAD; the four files were removed in `f617b96` and `.gitignore:49-53` carries the reason.
- **Full suite green on re-run**: 60 integration/arch files + all unit files PASS. (First `make test` run had 3 failures — `chat_respond_spec`, `cliproxy_lifecycle_spec`, `cliproxy_login_spec` — all green in isolation and green on the second full run. Pre-existing parallel-run flakiness, not this diff; flagged in §5.)

## 2. Critical

**BR-28 (re-raised, disposed `not-addressed`) — `init.lua:2181-2205`. The markdown × visual cell creates a child on disk and never commits the reference.** I rate this Critical this round because the diff also ships the contract it violates.

Measured, in a real foreign markdown buffer with an unrelated pending edit:

```
CHILDREN CREATED: { "2026-09-06.10-01-34.310.md" }
PARENT MODIFIED (uncommitted link): true
ON DISK HAS LINK: false
CHILD BACKLINK: 🌿: /private/tmp/.../notes.md:
```

`atlas/chat/inline_branch_links.md:18` says "creates the child on disk | … | **no** — it would be an orphan reachable only through an unsaved line", and `:22` says "**Visual mode**: … creates the child". The document contradicts itself on the same page, and the code follows the bullet, not the table.

Fix sketch — the class, not the cell: `commit_reference()` currently returns `false` for two different reasons ("not ours" and "write failed"), and only `insert_plain` distinguishes them. Give `insert_inline` the same `owns_file` branch: on a foreign buffer, splice the link, put the cursor after it, and create no child (the link is materialised by `open_branch_ref` when followed — exactly as the `n`/`i` path already relies on). Then extend `branch_child_spec`'s enumeration from `modes` to `modes × {chat, foreign}` with a per-cell expectation table, so the uncovered cell fails loudly rather than being discovered by a reviewer.

## 3. Important

**New — `init.lua:2110/2137`: ownership is re-derived from a mutable global at keypress instead of passed by the call site.** `branch_inserters(buf, abs_link)` takes the *link form* as a parameter but reads the *ownership* from `M._parley_bufs[buf]`, a map the highlighter maintains (`highlighter.lua:1063,1078,1138`). Both call sites already know the answer statically — `prep_chat` runs only for chat buffers, `setup_markdown_keymaps` only for markdown — so the one fact that decides three effects is the one fact not in the signature. Three consequences, all visible in this diff: `insert_inline` could skip the check without any signature saying it must not (it did); the spec has to poke private state (`parley._parley_bufs[buf] = "chat"`, `branch_child_spec.lua:77`) to reach the chat path, i.e. the test mocks the thing under test; and if the map is cleared (`BufUnload`, handle reuse) a real chat buffer silently degrades to foreign behaviour — no child, no write, no navigation — indistinguishable from a bug. Recommend `branch_inserters(buf, { abs_link = …, owns_file = … })`, both call sites passing literals. *(ARCH-ORDER, ARCH-MOCK.)*

**Re-raised (see the findings block for full dispositions):**

- **BR-20** — the rule is still not in force. Measured this round: reverting BR-10's `parent_ref` fallback leaves `branch_child_spec` 7/0/0; reverting BR-11 leaves `config_tools_spec` 26/0/0 and `keybindings_spec` 30/0/0; reverting BR-17 the same; reverting BR-21's function replacement leaves `branch_ref_spec` 9/0/0 and `branch_child_spec` 7/0/0. Four of four.
- **BR-21** — `branch_ref_spec.lua:53-66` calls `("topic: ?"):gsub("topic: %?", function() … end)` *in the test body*. It asserts that the test's own code is correct. Nothing calls `create_child_chat` with a `%` topic. Move the assertion to `create_child_chat(child, br.topic_for_selection('50% off'), …)` and read the header back.
- **BR-4** — `init.lua:2570-2577` still rebuilds `.i` around `md_branch.n`; the chat site passes the table through. The row the Plan checks says "so the pair cannot drift again"; half the pair still hand-wires.
- **BR-2** — `branch_ref_spec.lua` exists, but `atlas/traceability.yaml`'s `chat/inline_branch_links` block still lists four files and three specs; `branch_ref.lua`, `branch_ref_spec.lua` and `branch_child_spec.lua` appear nowhere, so `make test-changed` routes edits to the new module to nothing.
- **BR-23 / BR-31** — the instances were swept; neither rule shipped. No guard row asserts a doc names only keys in `resolve_keys(entry, config)`, and the new arch guard (`single_source_sweeps_spec.lua:378`) matches the literal `branch_prefix .. " " ..` idiom, which is why `chat_finder.lua:777`'s hand-built `"[" .. branch_prefix .. topic .. "](" .. rel_path .. ")"` is still invisible to it.
- **BR-29 / BR-30** — the atlas table is false for visual mode (above), and `init.lua:2078-2087` still says "`abs_link` is the only real difference between the buffer types" and "the child is created **with an empty topic**" — both contradicted 40 and 80 lines below by code the same commit wrote. The `## Revisions` section now exists, but of BR-30's three named deltas it records one (`<M-S-CR>` ordering); Row 1's `global_shortcut_branch_ref` and Row 3's "empty topic" are still stated as shipped.

## 4. Minor

- **BR-32** — `init.lua:2113` still drops the write error (`local ok = pcall(…)`); the warning has no cause. The log-ordering half is fixed.
- **BR-24** — `keybinding_registry.lua:478` and `config.lua:362` carry the same three-key list with nothing asserting they agree; M2's superset guard will compare against it.
- **BR-25** — `keybindings_spec.lua:331` `dofile("lua/parley/config.lua")` is still CWD-relative.
- **BR-26** — no `branch_ref_spec` case for a selection containing `](`, which is the one input that breaks the emitted link.
- **BR-18** — `.i()` is now driven, but nothing drains the scheduled `startinsert!`/`edit`; a reported ordering failure still has no reproduction.
- `init.lua:2147` and `:2167` call `M.highlight_chat_branch_refs(buf)` twice per keypress on the chat path (viewport-scoped and timer-debounced, so cheap — but the second call restarts the timer the first started).
- The Spec's "`<M-*>` family for terminal portability" item is unassigned: M1 added two more alt chords, including insert-mode `<M-i>`, and neither M1 nor M2 owns that review.

## 5. Test coverage notes

Suite is green (second full `make test` run: all files PASS; lint clean). What is *not* covered is uniform and matches the findings: the `markdown × v` and `markdown × i` cells (the broken one is `markdown × v`); `create_child_chat` with a pattern-metacharacter topic; the `parse_filename == nil` back-link fallback; the scope guard on `:ParleyToggleToolFolds`; the registry-callback/command identity `config_tools_spec.lua:434` claims in its title. Every one of those is a fix that reverts clean.

Separately: the **first** `make test` run failed 3 integration files (`chat_respond_spec:1978`, `cliproxy_lifecycle_spec`, `cliproxy_login_spec`), all of which pass in isolation and passed on the second full run. Not caused by this diff and not raised as a finding, but it means "suite green" is a one-in-two observation under `JOBS=8` — worth a `## Log` line so the close gate's evidence is honest about it.

## 6. Architecture

- **ARCH-DRY — flag.** BR-4 (markdown re-wraps `.i`), BR-31 (`chat_finder.lua:777` hand-builds the inline shape `splice_inline_link` owns), BR-24 (registry/config list duplicated). The `format_ref_line` consolidation itself is real and guarded — the remaining copies are the *inline* shape, which got no owner.
- **ARCH-PURE — pass with a caveat.** `branch_ref.lua` is genuinely pure and now tested without IO. The caveat is that purity was used as a substitute for coverage of the call site: BR-21's test exercises the pure helper and a hand-written copy of the impure caller.
- **ARCH-PURPOSE — flag.** "Extract one helper both buffer types call, so the pair cannot drift again" is checked; the pair drifted inside this milestone (the `v` cell), and one call site still re-implements. The findings the round disposed `addressed` were fixed at the site (`insert_plain`) with the enumerable sibling (`insert_inline`) left in the tree — the same instance-not-class pattern the last three rounds named.
- **ARCH-MOCK — flag (minor).** `parley._parley_bufs[buf] = "chat"` in the spec is a stateless poke at private state that decides behaviour; with ownership as a parameter the fake disappears.
- **ARCH-CONSTRAINTS — pass.** Keystroke path; one buffer `:write` and one viewport-scoped highlight pass (twice — see §4). Nothing unbounded.
- **ARCH-SECURE — flag.** The `gsub` replacement fix is correct but unpinned (BR-21); `splice_inline_link` still emits user text into a markdown link without escaping `](` (BR-26). No credential exposure at HEAD; BR-22's runtime state is gone from the index.
- **ARCH-ORDER — flag.** Two items: the `startinsert!`/`edit` schedule has no observable interleaving (BR-18), and ownership is carried in a mutable global read at event time rather than in the state the component was constructed with (§3, new finding). The second is what let one cell of the state space diverge from the other five.

## 7. Plan revision recommendations

- **M1 Row 1** still names `global_shortcut_branch_ref`; the shipped key is `chat_shortcut_branch_ref`. Add to `## Revisions`.
- **M1 Row 3** still says "create immediately with an **empty** topic"; the code ships `"?"` and the reason is load-bearing (auto-title + slug). BR-30 named this; the Revisions section does not record it.
- **M1 Row 2** is checked with the rationale "so the pair cannot drift again". Either narrow it to "one shared implementation; the markdown dispatch still wraps `.i`, and the `v` cell's buffer-type behaviour is M1-open", or leave it unchecked until BR-4 and BR-28 close.
- **New row (M1 or M2):** the `<M-*>` terminal-portability review the Spec asks for is in no milestone.

```findings
dispose:
  - id: BR-2
    disposition: not-addressed
    note: |
      Spec landed; atlas/traceability.yaml still has no branch_ref.lua, branch_ref_spec or branch_child_spec, so make test-changed routes the new module nowhere.
  - id: BR-4
    disposition: not-addressed
    note: |
      Chat site now passes the table through; init.lua:2570-2577 still re-implements .i around md_branch.n.
  - id: BR-10
    disposition: not-addressed
    note: |
      Measured: reverting parent_ref to the plain basename leaves branch_child_spec 7/0/0; the only path reaching the fallback is the markdown-visual cell BR-28 says must not create a child.
  - id: BR-11
    disposition: not-addressed
    note: |
      Measured: restoring the inline closure leaves config_tools_spec 26/0/0 and keybindings_spec 30/0/0; the added assertion checks the registry entry exists, not the identity.
  - id: BR-17
    disposition: not-addressed
    note: |
      Measured: deleting the _parley_bufs guard from M.cmd.ToggleToolFolds leaves both specs green; no test enters it.
  - id: BR-18
    disposition: not-addressed
    note: |
      .i() is driven now, but nothing drains or orders the scheduled startinsert!/edit, so no interleaving is observable.
  - id: BR-20
    disposition: not-addressed
    note: |
      Measured prevalence this round is 4/4 - BR-10, BR-11, BR-17 and BR-21 all revert clean with the suite green; no Log line names a red test per finding id.
  - id: BR-21
    disposition: not-addressed
    note: |
      branch_ref_spec.lua:53-66 runs the fixed gsub inside the test body; reverting init.lua's function replacement leaves branch_ref_spec 9/0/0 and branch_child_spec 7/0/0.
  - id: BR-22
    disposition: addressed
    note: |
      Files removed in f617b96 and .gitignore carries .local/ with the cause; git ls-files shows none at HEAD.
  - id: BR-23
    disposition: not-addressed
    note: |
      lifecycle.md and format.md were swept, but the guard row the rule called for was not added to single_source_sweeps_spec.lua.
  - id: BR-24
    disposition: not-addressed
    note: |
      keybinding_registry.lua:478 and config.lua:362 still carry the same list with nothing asserting they agree.
  - id: BR-25
    disposition: not-addressed
    note: |
      keybindings_spec.lua:331 still dofiles a CWD-relative path.
  - id: BR-26
    disposition: not-addressed
    note: |
      No case for a selection containing "](" in branch_ref_spec.
  - id: BR-27
    disposition: addressed
    note: |
      Pinned by branch_child_spec.lua:157-176 (cursor on the new line); the scheduled startinsert! half is still unasserted, which is BR-18.
  - id: BR-28
    disposition: not-addressed
    note: |
      Reproduced at HEAD: on a foreign markdown buffer insert_inline (init.lua:2199-2204) creates the child and commit_reference returns false without writing - the rule was applied to n/i only.
  - id: BR-29
    disposition: not-addressed
    note: |
      inline_branch_links.md:18 ("creates the child: no") contradicts :22 ("Visual mode ... creates the child") and the code follows :22; init.lua:2078-2082 still claims abs_link is the only difference and the topic is empty.
  - id: BR-30
    disposition: not-addressed
    note: |
      Revisions section exists but records one of the three named deltas; Row 1's global_shortcut_branch_ref and Row 3's "empty topic" are still stated as shipped.
  - id: BR-31
    disposition: not-addressed
    note: |
      chat_finder.lua:777 still hand-builds the inline link; the new guard matches only the `branch_prefix .. " " ..` idiom, not the emitted shape.
  - id: BR-32
    disposition: not-addressed
    note: |
      Log ordering fixed; init.lua:2113 still discards the pcall error so a failed write reports no cause.
findings:
  - id: new
    severity: Important
    family: state-rederived-instead-of-passed
    title: |
      branch_inserters reads ownership from the global M._parley_bufs at keypress instead of taking it from the call site that already knows
    detail: |
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
```

---

## Re-review — 2026-09-07T13:47:38-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 54a5c7a2ecaa3faf268d867f5222e73bd6f1dafb..d1f6aec3feb3cecb37e842241d270d375284911e |
| command | sdlc milestone-close --issue 214 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-07T13:47:38-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Round 6 is the first round where the milestone's *behaviour* holds up under mutation: I reverted each of round 5's four behavioural fixes one at a time in a clean clone and all four went red (BR-10 → 11/1, BR-17 → 11/1, BR-21 → 10/2, BR-28 → 11/1), and `make test` is green at HEAD (exit 0, full unit+integration+arch fan-out). The six-cell `modes × buffer types` spec is a real oracle, not theatre. What blocks SHIP is not the branch code: it is that the *classes* three rounds have now named are still unswept. BR-21 was fixed at `create_child_chat` while four enumerable siblings put user text into a `gsub` **replacement** — and one of them, `init.lua:3936`, is the child-creation path M1's own markdown decision ("the child is created when the link is followed") routes every markdown branch to; I measured the runtime behaviour in this nvim's LuaJIT and it does not raise, it silently corrupts (`50% off` → `50 off`, `%1 x` → `{{topic}} x`, a trailing `%` writes a NUL byte). Alongside that: BR-11's fix reverts clean for the fourth consecutive round, BR-23's and BR-31's rule-guards still do not exist, and the `## Revisions` section the close gate's plan-unchecked guard reads still omits two of BR-30's three named deltas.

## 1. Strengths

- **`create_child_if_owned` (`lua/parley/init.lua:2115-2120`) makes the invariant structural.** Neither mode can call `create_child_chat` directly any more. I verified it is load-bearing: restoring the direct call in `insert_inline` turns `branch_child_spec` red.
- **The six-cell spec iterates both axes** (`tests/integration/branch_child_spec.lua:200-231`) and asserts the dispatch table's key set (`:137-141`), so adding a mode or a buffer type without coverage fails rather than passes silently.
- **BR-21's tests were moved onto the real entry point.** `branch_child_spec.lua:236-274` drives `create_child_chat`; reverting the function replacement fails 2. The previous version of these tests ran the fixed `gsub` in the test body — that trap is closed.
- **`atlas/ui/keybindings.md:33-46` is measured, not inferred.** The resolution table matches `resolve_keys` cell for cell, including the three fall-through shapes, and it is the artifact M2 will build its superset guard against.
- **`workshop/lessons.md:1259-1296`** is an honest post-mortem — "consolidating implementations ≠ erasing situational differences" is the rule that actually explains all three Criticals.

## 2. Critical findings

None.

## 3. Important findings

**I6-1 — the `%`-in-replacement class was fixed at one site; four siblings remain, one of them on the path M1 chose for markdown.**
*This is the 2nd finding in family `user-text-unescaped-in-lua-pattern`.* Do NOT fix the instance — state the rule and sweep the enumeration in this round.

Rule: **a runtime string may never be the second argument to `gsub`/`sub` — use a function replacement, or `%`-escape.** The enumeration is `grep -n ':gsub(' lua/parley/*.lua` filtered to calls whose replacement is not a string literal. Surviving sites at HEAD:

| site | replacement | reachable from |
|---|---|---|
| `init.lua:3936` | `topic` (user text) | `<C-g>o` on a `🌿:` line whose child does not exist — **the markdown branch path M1 shipped** |
| `init.lua:4079` | `topic` | `@@ref:` chat creation |
| `init.lua:4241` | `topic` | same, second copy |
| `init.lua:3272` | `initial_question` | `M.cmd.ChatReview` (embeds a file path) |

Measured in this repo's runtime, not assumed — LuaJIT does **not** raise:
```
rep="50% off"        -> "50 off"          (character silently dropped)
rep="%1 placeholder" -> "{{topic}} …"     (capture substituted)
rep="100%"           -> "100\0"           (NUL written into the file)
```
So the failure is silent corruption of the child's `topic:` header, not a visible error. Fix sketch: one shared helper (`branch_ref` is the natural owner) or `gsub(pat, function() return v end)` at each site, plus a spec per site driving the real entry point. Note `init.lua:3930-3950` and `:4060-4085` are two hand-rolled re-implementations of `create_child_chat` — collapsing them onto `create_child_chat` fixes the class and removes the duplication in one move. ARCH-SECURE, ARCH-PURPOSE, ARCH-DRY.

**Also open and re-raised by id (details in the findings block):** BR-2 (traceability), BR-4 (markdown re-wraps `.i`), BR-11 (identity still unpinned, 4th round), BR-18 (no ordering seam), BR-20 (rule not in the Log), BR-23 (guard row), BR-28→addressed, BR-29 (atlas), BR-30 (Revisions), BR-33→addressed.

## 4. Minor findings

- `branch_inserters(buf, abs_link, owns_file)` — two independent booleans encode one bit; `(true,true)` and `(false,false)` are representable and untested (new finding, below).
- `init.lua:2126` still drops the `pcall` error (BR-32); `init.lua:2218` logs *"Created inline branch to new chat"* on the foreign-markdown path where no child was created.
- `M.cmd.ToggleToolFolds`'s guard is `not M._parley_bufs[buf]`, which also admits parley-managed **markdown** buffers, while the warning reads "parley chat buffers only".
- `keybindings_spec.lua:350` `dofile("lua/parley/config.lua")` still CWD-relative (BR-25).
- `keybinding_registry.lua:478` still byte-duplicates `config.lua:362` (BR-24).
- `branch_child_spec.lua:77` still pokes `parley._parley_bufs[buf] = "chat"`; since BR-33 it is vestigial.

## 5. Test coverage notes

Verified by mutation in a clean clone of `d1f6aec` (full suite green at baseline):

| fix | revert | result |
|---|---|---|
| BR-28 `create_child_if_owned` in `insert_inline` | direct `create_child_chat` | `branch_child_spec` **11/1** ✅ |
| BR-21 function replacement | string concat | **10/2** ✅ |
| BR-10 `parent_ref` fallback | bare `parent_rel` | **11/1** ✅ |
| BR-17 buffer guard | remove guard | **11/1** ✅ |
| BR-11 `= M.cmd.ToggleToolFolds` | inline closure | `config_tools` 26/0, `keybindings` 30/0, `branch_child` 12/0 ❌ |
| BR-33 ownership from call site | re-read `M._parley_bufs` | 12/0 ❌ |

Uncovered: the entire markdown dispatch table (`init.lua:2583-2590` — no spec calls `setup_markdown_keymaps`); the `vim.schedule(edit → G → startinsert!)` that README and the atlas both advertise as "opens the child" — the run leaks it, emitting `E211: File ".../plain-notes.md" no longer available` and three out-of-order log lines *after* the suite summary, which is the unbounded-extent symptom, not a cosmetic one.

## 6. Architectural notes

- **ARCH-DRY — flag.** BR-4 (markdown rebuilds `.i`), BR-31 (`chat_finder.lua:777` hand-builds the inline shape `splice_inline_link` owns; the guard is keyed on one concatenation spelling), BR-24, plus the two `create_child_chat` re-implementations named in I6-1.
- **ARCH-PURE — pass, with a caveat.** `branch_ref.lua` is genuinely pure and now has 7 IO-free tests. The caveat: the three extracted functions are the trivial half; the ownership branch and the ordering both stayed inside the IO closure, reachable only through the private `M._branch_inserters` seam.
- **ARCH-PURPOSE — flag.** Three rounds have now named a class and had the instance fixed: BR-21 (I6-1 above), BR-23 and BR-31 (instances swept, neither guard written). The shadow-sweep for "one formatter" passes for the `🌿: path: topic` shape and fails for the `[🌿:text](path)` shape, which has no owner in production code.
- **ARCH-MOCK — pass.** No new external binary or service; the filesystem is exercised through real scratch dirs, the repo's existing seam.
- **ARCH-CONSTRAINTS — pass.** `commit_reference`'s synchronous `:write` is on a keystroke path but is bounded and deliberate; no unbounded fan-out introduced.
- **ARCH-SECURE — flag.** I6-1 (user text into `gsub` replacements, measured silent corruption + a NUL byte). Residual: `splice_inline_link` still emits user text into a markdown link without escaping `](` (BR-26). No credential exposure; `git ls-files | grep '^\.local'` is empty and `.gitignore:49-53` carries the reason.
- **ARCH-ORDER — flag.** BR-18: `M._branch_inserters` is a *call* seam, not an ordering seam — no test can inject or observe the `stopinsert` → `schedule(edit + startinsert!)` interleaving, and the scheduled work outlives its scope (measured E211 above). Second: `(buf, abs_link, owns_file)` is a two-flag constellation declaring four states where two are legal, with the call sites passing mirrored literals `(false, true)` and `(true, false)` — collapse to one `kind` parameter so the guarantee table BR-33 asked to encode in the signature actually is.

## 7. Plan revision recommendations

Append to `## Revisions` (do not edit the rows):

1. **Row 1's config key is `chat_shortcut_branch_ref`, not `global_shortcut_branch_ref`.** The `chat_` prefix is the shipped convention for `parley_buffer`-scoped entries (`chat_shortcut_open_file`, `chat_shortcut_copy_fence` are the precedents), so the Plan's name was wrong, not the code's.
2. **Row 3 ships `topic: "?"`, not an empty topic.** `""` disabled auto-titling and the slug rename (BR-1); `?` is the sentinel the lifecycle keys off. The existing Revisions section records the chord order and the buffer-type divergence but not this.
3. **Row 2's rationale is narrower than its text.** "so the pair cannot drift again" holds for `n` and `v`; `setup_markdown_keymaps` (`init.lua:2584-2589`) still hand-wires `.i`. Either narrow the rationale or leave the row unchecked until BR-4 closes.
4. Add an **M3 scope line** (or an M2 row) for I6-1's sweep if the operator judges the `{{topic}}` class out of M1 — but record the deferral explicitly; it is currently neither fixed nor written down.

```findings
dispose:
  - id: BR-2
    disposition: not-addressed
    note: |
      branch_ref_spec ships and passes 7, but atlas/traceability.yaml:141-150 still lists only the four old code files and three old tests - branch_ref.lua, branch_ref_spec.lua and branch_child_spec.lua are all absent, so make test-changed still routes nothing to them.
  - id: BR-4
    disposition: not-addressed
    note: |
      Chat passes the table through (init.lua:2391); init.lua:2584-2589 still rebuilds .i around md_branch.n, so half the pair hand-wires and the Plan row claiming "the pair cannot drift again" is still not true.
  - id: BR-10
    disposition: addressed
    note: |
      Verified by revert: parent_ref -> bare parent_rel leaves branch_child_spec 11/1.
  - id: BR-11
    disposition: not-addressed
    note: |
      Verified by revert for the 4th round: an inline closure at init.lua:2429 leaves config_tools_spec 26/0, keybindings_spec 30/0 and branch_child_spec 12/0. The new test asserts the registry ENTRY exists, not that its callback IS M.cmd.ToggleToolFolds.
  - id: BR-17
    disposition: addressed
    note: |
      Verified by revert: removing the guard leaves branch_child_spec 11/1. Minor residual - the guard is `not M._parley_bufs[buf]`, so it also admits parley markdown buffers while the warning says "chat buffers only".
  - id: BR-18
    disposition: not-addressed
    note: |
      M._branch_inserters is a call seam, not an ordering seam. Nothing flushes or observes the schedule(edit -> G -> startinsert!), and the run leaks it - E211 "File .../plain-notes.md no longer available" plus three log lines printed after the suite summary.
  - id: BR-20
    disposition: not-addressed
    note: |
      Improved but not in force. Measured this round 4/6 pin (BR-10, BR-17, BR-21, BR-28 all go red on revert); BR-11 and BR-33 revert clean. The issue's Log still names no test per finding id - those statements live only in the commit body.
  - id: BR-21
    disposition: addressed
    note: |
      Verified by revert: string concat leaves branch_child_spec 10/2. The site is fixed and pinned; the CLASS is not - see the new finding.
  - id: BR-23
    disposition: not-addressed
    note: |
      Instances swept (verified - only alias mentions remain in README/ARCH/atlas/lua). The rule half was not delivered: no guard row asserts a doc names only keys in resolve_keys(entry, config); the one new arch row is about the branch-ref formatter.
  - id: BR-24
    disposition: not-addressed
    note: |
      keybinding_registry.lua:478 and config.lua:362 still carry the same three-key list with nothing asserting they agree.
  - id: BR-25
    disposition: not-addressed
    note: |
      keybindings_spec.lua:350 dofile("lua/parley/config.lua") is still CWD-relative.
  - id: BR-26
    disposition: not-addressed
    note: |
      branch_ref_spec has no case for a selection containing "](", nor for one ending in a multibyte character.
  - id: BR-28
    disposition: addressed
    note: |
      Verified by revert: restoring the direct create_child_chat in insert_inline leaves branch_child_spec 11/1. The six-cell spec iterates both axes and fires.
  - id: BR-29
    disposition: not-addressed
    note: |
      The two named claims are gone, but three new unverified ones landed in the same file - :7 states the signature as branch_inserters(buf, abs_link) when it takes three params; :22 says visual mode "creates the child" unconditionally, contradicting the table four lines above for foreign markdown; the table's "after the keypress = opens the child" is false for the chat x visual cell, which stays in the parent; and :36 "Child gets a parent back-link" is false for the markdown full-line path, which routes through init.lua:3939 where the back-link is skipped for a non-chat source. No spec exercises any atlas or README claim, which is the rule half that keeps not shipping.
  - id: BR-30
    disposition: not-addressed
    note: |
      Revisions records the chord order, the tool-fold decision and the buffer-type divergence. Two of BR-30's three named deltas are still missing - Row 1's global_shortcut_branch_ref (code ships chat_shortcut_branch_ref) and Row 3's "empty topic" (code ships "?"). Row 2 is still [x] on "so the pair cannot drift again" while init.lua:2584-2589 re-implements .i.
  - id: BR-31
    disposition: not-addressed
    note: |
      chat_finder.lua:777 is unchanged and the guard at single_source_sweeps_spec.lua:381 still matches the literal `branch_prefix .. " " ..` idiom, so the inline shape splice_inline_link owns has no owner and no guard.
  - id: BR-32
    disposition: not-addressed
    note: |
      The log-ordering half is fixed. init.lua:2126 still writes `local ok = pcall(...)`, dropping the cause. Sibling in the same function - init.lua:2218 logs "Created inline branch to new chat" on the foreign-markdown path where no child was created.
  - id: BR-33
    disposition: addressed
    note: |
      Both call sites now pass ownership (init.lua:2296, :2565) and neither mode reads M._parley_bufs. Residual raised separately as a Minor - two independent booleans do not encode the guarantee table in the signature the way the finding asked. branch_child_spec.lua:77's poke is now vestigial.
findings:
  - id: new
    severity: Important
    family: user-text-unescaped-in-lua-pattern
    title: |
      BR-21 was fixed at one site; four gsub-replacement siblings survive, one of them the child-creation path M1 routes markdown branches to
    detail: |
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
  - id: new
    severity: Minor
    family: illegal-state-representable-in-signature
    title: |
      branch_inserters takes two independent booleans that encode one bit, so two of the four representable states are illegal and untested
    detail: |
      init.lua:2090 - branch_inserters(buf, abs_link, owns_file). The two call sites pass
      exactly mirrored literals, (buf, false, true) at :2296 for chat and (buf, true, false)
      at :2565 for markdown, and branch_child_spec hand-writes the same pairs at five
      places. (true, true) and (false, false) are representable, mean nothing, and no test
      covers them. BR-33's stated purpose was that "the guarantee table is enforced by the
      signature rather than by a comment"; two independent booleans do not do that. Collapse
      to one tagged parameter - kind = "chat" | "foreign" - and derive both facts from it.
      ARCH-ORDER.
```
