# Boundary Review — parley.nvim#214 (milestone M2)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | b17f4761101430bea7ed5780b240b8f8e18e8ab9..479b59e113d1ac4eb76d241f622f962b7230f84f |
| command | sdlc milestone-close --issue 214 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-07T14:33:09-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M2's structural core is real and well-guarded: all 81 registry entries now carry a `config_key`, `resolve_keys` makes an explicit `shortcut` authoritative in both directions, and the two headline guards (superset, no-leaks) are genuinely red-verifiable — I reverted each in a scratch copy and watched them fail. The suite is green (198 spec files, `make test` exit 0, lint clean). What blocks SHIP is that the milestone's own single-source thesis stops at the registry table and never reaches the *install* seam: three review-skill keymaps and ~20 picker keymaps are still built by reading `config.X.shortcut` directly, so (a) `default_keymaps = false` leaves four parley mappings live on every markdown buffer, and (b) the README's newly-documented `shortcut = ""` disable gesture raises `Invalid (empty) LHS` — measured, not inferred. Separately, giving `md_delete_file` the shared `chat_shortcut_delete` knob widened a **file-deleting** binding from normal-mode-only to `n/i/v/x`, inside a milestone whose Plan explicitly declares itself behaviour-free; the superset guard built to catch exactly this hazard only inspects `shortcut`, not `modes`.

## 1. Strengths

- **The agreement spec is not decorative.** I planted `vim.keymap.set("n","<C-g>ZZ",…,{desc="Parley: planted leak"})` in `prep_chat` and `tests/integration/keybinding_agreement_spec.lua:76` went red on all three relevant cases. The `keytrans(replace_termcodes(...))` normalization at `:56` is the right fix for the `<C-g>`/`<C-G>` trap and is applied to *both* sides.
- **The superset guard is red-verifiable.** Shipping `chat_shortcut_drill_in = { shortcut = "<C-g>q" }` in a scratch copy failed `tests/unit/keybindings_spec.lua:404` with `chat_drill_in loses <M-q> via chat_shortcut_drill_in`, plus the resolver-level twin at `:427`. Two layers, one hazard — exactly what PQ-1 asked for.
- **BR-9's fix is stated as a rule, not a patch.** `keybinding_registry.lua:1013-1021` — "an explicit `shortcut` is authoritative in BOTH directions" — with the strategy table pinned across eight shapes (`tests/unit/keybindings_spec.lua:435-489`), including `{ "", "" }`. The comment records *why* the old `or` chain looked like it worked.
- **`opt_in` is closed in both directions** (`tests/unit/keybindings_spec.lua:497-520`). An entry cannot lose its key silently, and the superset guard's skip for opt-in entries is backstopped by the "really does ship unbound" test, so the skip can't hide shrinkage.
- **`native_map` enforces the exemption instead of trusting it** (`init.lua:2306-2320`). Recording the rationale in `native_overrides` and refusing an unlisted key turns "we decided these are fine" into a mechanism.
- **The typeahead gate is measured across the matrix that matters** — the `nil` row is first, and `spell_chat_spec.lua:184` reads the shipped file rather than the merged config.

## 2. Critical findings

### C1 — `default_keymaps = false` leaves four maps live on markdown buffers, and `shortcut = ""` raises

`lua/parley/skills/review/init.lua:759,772,788` (and ~20 picker sites) install keymaps from `cfg.review_shortcut_*.shortcut` directly, never touching `resolve_keys`. Both of M2's new guarantees route through `resolve_keys`, so neither reaches them.

Measured, on a plain `.md` buffer with `default_keymaps = false`:

```
MAPS-OFF: { "i <M-CR> :: Parley review: open mode menu",
            "n <C-G>ve :: Parley review: process markers",
            "n <M-CR> :: Parley review: open mode menu",
            "n <M-o>  :: Parley: open skill picker" }
```

Done-when says "verified by `:map` showing no parley mapping afterwards"; README.md:252 says "disable ALL of parley's default keymaps"; `atlas/ui/keybindings.md` says the switch covers "every registry-derived binding". All three are false — these *are* registry entries (`review_edit`, `review_menu`, `review_next`, `help_only`). The config carve-out at `config.lua:334-338` names "the review menu" as a transient window, but `<M-o>`/`<M-CR>`/`<C-g>ve` are the keys that *open* it, not keys inside it.

Second symptom, same root, worse: README.md:249 now documents `shortcut = ""` as the way to disable one binding. Applied to `review_shortcut_edit`:

```
Error executing lua callback: vim/keymap.lua:0: Invalid (empty) LHS
  ./lua/parley/skills/review/init.lua:759: in function 'setup_keymaps'
  ./lua/parley/init.lua:2573: in function 'setup_markdown_keymaps'
  ./lua/parley/highlighter.lua:1080  (BufEnter)
```

— i.e. an error on *every markdown file the user opens*. `float_picker.open` with `{ key = "" }` raises the same way (measured directly), so the gesture also breaks `global_shortcut_keybindings` and all 15 `*_finder_mappings.*` entries.

**Fix (the class, not the site — `ARCH-PURPOSE` shadow-sweep, `ARCH-DRY`):** every keymap parley installs from a registry entry's config must derive from `resolve_keys`. Enumerate the consumers and convert them: `skills/review/init.lua:759,772,788`; `chat_finder.lua:826,865,895,917,921,926,930,935`; `note_finder.lua:412,439,440,442`; `issue_finder.lua:535,564,591,595,600`; `agent_picker.lua:242`; `root_dir_picker.lua:211`; `system_prompt_picker.lua:121`; `outline.lua:383,423`. Then extend `keybinding_agreement_spec` to a **markdown** buffer and a **note** buffer — the leak/ghost machinery already catches this once it looks there. If pickers stay out of the master switch by design, the switch must stop suppressing their help rows too (today `<C-g>?` inside a finder goes blank while `<C-x>` still deletes — help and reality disagree in the *other* direction, contradicting `atlas/ui/keybindings.md`'s claim).

### C2 — `md_delete_file` widened from `n` to `n/i/v/x` by adopting a shared `config_key`

`lua/parley/keybinding_registry.lua:705` adds `config_key = "chat_shortcut_delete"` to an entry whose `default_modes = { "n" }`. `chat_shortcut_delete` ships `modes = { "n", "i", "v", "x" }` (`config.lua:348`), and `resolve_keys` line 1010 does `local modes = cfg_val.modes or entry.default_modes` — config wins. Measured on a plain markdown buffer:

```
md_delete_file keys={"<C-g>d"} modes={"n","i","v","x"}  default_modes={"n"}
MAP n <C-G>d :: Parley delete current file and buffer
MAP i <C-G>d :: Parley delete current file and buffer
MAP v <C-G>d :: Parley delete current file and buffer
MAP x <C-G>d :: Parley delete current file and buffer
```

A file-deleting action is now reachable from insert mode (where `<C-g>` is a native prefix) and visual mode, in **any** markdown file. It is `confirm()`-guarded with `&No` as default, so nothing is destroyed silently — but the Plan states plainly that "M2 is pure policy … This is behaviour", and this is behaviour, undeclared, on the destructive path.

> **This is the 2nd finding in family `config-shadows-default-key`.** Do not just pin `md_delete_file`'s modes. **The rule:** when an entry adopts a `config_key`, *every* field the config carries replaces the entry's declared default — not only `shortcut`. The superset guard at `tests/unit/keybindings_spec.lua:391` inspects `cfg.shortcut` alone, which is why this walked through it. **The enumeration:** for each entry with a `config_key`, assert `default_modes ⊆ resolved modes` *and* `default_key ⊆ resolved keys`, in the same loop; that closes shrinkage and widening for all 81 entries at once, including the three md/chat twins (`chat_shortcut_delete_tree` and `chat_shortcut_export_html` happen to be `{ "n" }`, so only `chat_shortcut_delete` is live today — one instance out of three is what makes it a rule worth encoding rather than a typo worth fixing).

## 3. Important findings

### I1 — "every feature stays reachable as a `:Parley*` command" is false

README.md:252-253 and `atlas/ui/keybindings.md` promise it; `keybinding_agreement_spec.lua:130` "verifies" it by checking four hand-picked names that happen to exist. Enumerating all 64 `Parley*` commands against all 81 registry ids, these have **no command**: `chat_drill_in` (`<M-q>` — the headline quote gesture), `branch_ref` (`<M-i>`/`<M-S-CR>`, M1's headline chord), `chat_accept_drill_in` (`<M-a>`), `chat_reject_drill_in` (`<M-r>`), `skill_picker` (`<M-o>`), `md_add_chat_ref`, `chat_search`, `super_repo_toggle`. A user who follows the README's `default_keymaps = false` advice loses `<M-q>` with no way back.

> **This is the 4th finding in family `docs-assert-unverified-behavior`.** Do not fix the sentence. **The rule:** a user-facing promise quantified over a set ("every feature", "no `<leader>` key", "all default keymaps") must be pinned by a test that *derives* the set from the source, never by an allowlist a human typed. **Prevalence:** four rounds, four instances. The enumeration here is one loop — for each non-`help_only` registry entry, assert a `:Parley*` command exists, and either add the missing commands or narrow the README to the truth. The same rule retro-fixes `keybinding_agreement_spec.lua:130` and is what the `<leader>` test at `keybindings_spec.lua:511` already does correctly — copy that shape.

### I2 — `<C-g>?` still cannot show aliases; the Done-when it closes is unmet

Done-when: "No **registry-derived** binding exists that `<C-g>?` cannot show — asserted in both directions." Measured against the shipped config, the chat help float renders `<C-g>t` for outline and `<M-i>` for branch_ref; `<M-q>`, `<M-t>`, `<M-S-CR>` and `<C-g>i` appear nowhere. The M1 Log explicitly deferred this to "M2's help/reality criterion, **which will render aliases** rather than reorder more keys". M2 ticked that Plan row without rendering aliases; `atlas/ui/keybindings.md:73` now documents alias-invisibility as accepted, but neither the Done-when nor a `## Revisions` entry records the reversal. The new agreement spec asserts registry↔keymaps, not registry↔help — so the direction the Done-when names is the one left uncovered.

> **This is the 2nd finding in family `plan-not-revised-after-decision-change`.** Do not just add the missing Revisions paragraph. **The rule:** before ticking a Plan row, re-read every Done-when bullet and every "M-next will…" sentence the earlier Log wrote, and for each one either point at the assertion that closes it or write the `## Revisions` entry that retires it — in the same commit that ticks the row. The atlas is not the place a superseded commitment gets recorded; the issue is.

## 4. Minor findings

- `keybinding_registry.lua:1085` — `resolve_display_shortcut`'s `_bufnr` is now dead (the docstring still names it `bufnr` and calls it "unused; kept for call-site compatibility"); `help_lines` threads a `bufnr` nothing reads. Drop it from both, or state what future call site needs it. *(2nd in `dead-value-in-new-code` — the rule: a parameter kept "for compatibility" needs a named caller that requires it, or it goes.)*
- `keybinding_agreement_spec.lua:155-165` — "reversible within one session" only observes fresh buffers. `_prepared_bufs` short-circuits `prep_chat`, so flipping `default_keymaps` and re-running `setup()` leaves already-open buffers exactly as they were; the test cannot see that interleaving. *(3rd in `no-seam-for-ordering` — the rule: a test whose name quantifies over a session must exercise state that survives the flip, not only state created after it.)*
- `init.lua:2312` — `native_map` raises inside `prep_chat`, which runs from `BufEnter` *after* `M._prepared_bufs[buf] = true` (line 2248). A mis-registered key therefore leaves the buffer permanently half-prepared with no retry. Dev-triggerable only, but the guard would be strictly better as a spec assertion over `prep_chat`'s source than as a production `error()`.
- `config.lua:419-421` — the three new `note_shortcut_*` keys are the only user-facing config surface this milestone adds that the README doesn't mention.
- Upgrade path: existing users silently lose five `<leader>` maps, `<leader>fo`, and the spell typeahead. README documents the new *defaults* but not that they changed; the repo has no CHANGELOG convention, so a line in the README's Keybindings section is the cheapest place.

## 5. Test coverage notes

- Two guards verified red by reversion (superset, no-leaks) — those are load-bearing.
- The leak/ghost machinery is sound but **scoped to chat buffers**. `keybinding_agreement_spec.lua:98` filters ghosts to `scope == "chat" or "parley_buffer"`, and both tests prep only a chat buffer — so `markdown`, `note`, `global`, `issue`, `vision` and `repo` scopes are unverified. C1 lives entirely in that blind spot; extending the spec to a markdown buffer *is* the C1 fix's own test.
- No assertion covers `modes` (C2). The strategy table at `keybindings_spec.lua:435` tests `modes` fallback for a synthetic entry but never asserts modes against real shipped entries.
- `keybindings_spec.lua:472,501,513` skip every dotted `config_key` (15 picker entries), so the "every registry entry can actually be disabled" claim is proven for 66 of 81. The skip is undocumented in the test and unqualified in the README.
- `keybinding_agreement_spec.lua:130` asserts a hand-typed command list (see I1).

## 6. Architectural notes

- **ARCH-DRY — flag (C1).** Key→keymap derivation exists twice: the governed `resolve_keys`, and ~20 ungoverned `config.X.shortcut` reads. Every guarantee M2 adds attaches to the first copy only.
- **ARCH-PURE — pass.** `resolve_keys` is a clean `(entry, config) -> (keys, modes)`; the strategy table runs with no IO. `opt_in`/`native_overrides` are pure data. `native_map` and `spell.attach`'s gate are thin seams. This is the part of the diff that will age well.
- **ARCH-PURPOSE — flag (C1, I1).** The issue's own words: "the registry is the single source only if *every* binding derives from it — ten exceptions make it a partial source." The diff closes the exceptions in the *entry table* and leaves them open at the *install seam*. The shadow-sweep is the deliverable here, not a follow-up.
- **ARCH-MOCK — N/A.** No external binary or service in the window; tests exercise real Neovim keymap APIs at the correct boundary.
- **ARCH-CONSTRAINTS — pass, with a win.** Keystroke path: the master switch is an O(1) early return, and gating typeahead removes a `TextChangedI` autocmd plus a `<CR>` map from every chat buffer by default. No new per-keystroke work.
- **ARCH-SECURE — N/A** for untrusted input/credentials. One note: the `error()` in `native_map` fires on a user's buffer for a developer's mistake (see Minor).
- **ARCH-ORDER — flag (minor).** `default_keymaps` is sampled at install time and `_prepared_bufs` makes that sample permanent per buffer; the test that claims reversibility observes only the post-flip interleaving.

## 7. Plan revision recommendations

1. **`## Revisions` — "`<C-g>?` renders `keys[1]` only; alias rendering not delivered in M2 (I2)."** Record that the M1 Log's commitment ("M2's help/reality criterion, which will render aliases") was not met, say whether it is accepted permanently or moves to M3, and amend the Done-when bullet so it stops asserting what the code does not do.
2. **`## Revisions` — "master switch scope, as built."** The carve-out list in `config.lua:334-338` and `atlas/ui/keybindings.md` does not match behaviour: `<C-g>ve`/`<M-o>`/`<M-CR>` stay bound on every markdown buffer and are not "keys inside a transient window". Restate the switch's true extent, or fix C1 and delete the discrepancy.
3. **`## Revisions` — "`md_delete_file` mode set changed by the shared knob (C2)."** The shared-`config_key` decision is recorded in the Log as a key-level change; its mode-level consequence is not. Record it, or revert to `default_modes` and note why the twins share keys but not modes.
4. **Add the `## Core concepts` table** the M1 boundary review recommended (`workshop/plans/000214-…-m1-review.md:771`, item 5). It is still absent, and M2 added a config surface, an `opt_in` table, a `native_overrides` table and a new integration spec with no table-vs-code cross-check.
