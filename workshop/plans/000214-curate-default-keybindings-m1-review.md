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
