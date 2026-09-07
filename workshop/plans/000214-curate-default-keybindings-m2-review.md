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

---

## Re-review — 2026-09-07T15:05:18-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | b17f4761101430bea7ed5780b240b8f8e18e8ab9..db11196d754f21972870f4d3eb213ebe3981753f |
| command | sdlc milestone-close --issue 214 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-07T15:05:18-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I've completed the review — full suite run, plus reversion verification of each claimed fix and desc-independent measurement of the master switch.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Both prior Criticals are genuinely fixed, and I verified each by reverting it in a scratch copy and watching a test go red — C2 (`md_delete_file` mode widening) fails two guards; C1 fails the arch sweep and two markdown-agreement tests; the `_explicit_shortcuts` carve-out fails two switch tests; the `help_only` guard fails when a non-picker entry re-adopts the flag. The shadow-sweep is complete and measured, not asserted: zero `.shortcut` and zero `.modes` reads remain outside the registry across all 147 Lua files, and I confirmed desc-independently (by diffing `nvim_get_keymap`/`nvim_buf_get_keymap` before and after) that `default_keymaps = false` installs **nothing** — global, chat-buffer, or markdown-buffer. `make test` is green (198 spec files, exit 0, lint included). What keeps this from SHIP is that the switch's *reversibility* story was written for buffers only: a second `setup()` that turns the switch off leaves 43 global parley mappings live, and the docs describe the limitation as buffer-local. Alongside that, the milestone's headline leak guard depends on an unenforced convention (a `desc` containing "parley"), and two universal claims are pinned over hand-narrowed subsets.

## 1. Strengths

- **The C1 class fix is the real one.** `skills/review/init.lua:747` returning `registry_callbacks` instead of installing, with `init.lua:2603` handing them to `register_buffer`, inverts the dependency correctly — the skill supplies behaviour, the registry owns installation. Combined with the `help_only`-scope guard (`tests/arch/single_source_sweeps_spec.lua:495`), the exemption that hid the shadow installs is now itself enforced.
- **Every fix is pinned by a test I watched go red.** Four independent reversions, four red suites. This is the discipline the "claimed fixes" check exists to find missing, and it is present.
- **C2's fix is stated as a rule, not a patch.** `tests/unit/keybindings_spec.lua:404` covers keys *and* modes in one loop, and the "entries sharing a `config_key` declare identical defaults" test at `:437` is the general statement of why the twin pattern was wrong — it fires with `chat_shortcut_delete: chat_delete vs md_delete_file`.
- **The master switch is honest at the seam.** Living inside `resolve_keys` (`keybinding_registry.lua:966`) rather than in the installers is what makes help and reality agree; I measured 0 added mappings in all three scopes with it off.
- **`workshop/lessons.md:1297-1389`** is unusually good: "a green test can be green for a reason that doesn't generalise" names the shared-fixture failure precisely, and "a flag that says 'handled elsewhere' is an inventory of your blind spots" is the transferable rule.

## 2. Critical findings

None.

## 3. Important findings

### The master switch is not reversible for global maps, and the docs only admit the buffer half
`lua/parley/init.lua:867` / `lua/parley/config.lua:334-341`. `register_global` samples `default_keymaps` once per `setup()` and has no teardown. Measured (desc-independent keymap diff): `setup()` then `setup({ default_keymaps = false })` leaves **43** global parley mappings — `<C-G>c`, `<C-G>f`, `<C-G>w`, all seven `<C-J>*`, all `<C-N>*`, all `<C-Y>*`. `config.lua:340` says only "Sampled when a buffer is prepared … buffers already open keep what they were given"; `atlas/ui/keybindings.md` repeats the buffer-scoped framing. Neither mentions globals, so the README's Done-when procedure (`:map` shows no parley mapping) fails in the most natural way to try the switch: flipping it interactively and re-running `setup()`.

**This is the 3rd finding in family `no-seam-for-ordering`.** Round 8 raised the buffer half as a Minor ("reversibility only observes fresh buffers"); this round fixed and documented buffers and never looked at the other sample site. Do not just patch globals. **The rule:** every site that *samples* `default_keymaps` is a place the switch's decision becomes durable state, so each needs a stated reversibility rule and an assertion. **The enumeration** is three sites — `register_global` (setup-time, global maps, no teardown), `register_buffer` via `prep_chat`/`setup_markdown_keymaps` (buffer-local, guarded by `_prepared_bufs`), and `native_map` (`init.lua:2341`, same guard). Write the rule for all three; either add a teardown pass over previously-installed global maps, or state in `config.lua` + atlas that the switch is read once at `setup()` for globals and re-`setup()` does not revoke them.

### The no-leaks guard's oracle depends on a convention nothing enforces
`tests/integration/keybinding_agreement_spec.lua:71-79`. `parley_maps` filters buffer keymaps by `m.desc:lower():find("parley")`. **46 of 81** registry entries carry a `desc` with no "parley" in it (`"Create New Chat"`, `"Delete selected chat"`, `"Cycle recency window left"` …). They happen to all be non-`buffer_local` today, which is the only reason the guard works — nothing asserts it. A hand-rolled `vim.keymap.set` with no `desc`, or one described "Delete selected chat", is invisible to both the leak test and the `default_keymaps = false leaves no parley mapping` test — i.e. to exactly the failure mode the guard exists to catch. Separately, the allowance list omits a category the code's own docs declare: `config.lua:337` and `atlas/ui/keybindings.md` bless feature-gated maps (`chat_spell.typeahead`'s `<CR>`, interview's) as a third kind, but running the leak test with `chat_spell = { typeahead = true }` fails with `<CR> (parley: accept spell suggestion / newline)` — measured.

**This is the 2nd finding in family `test-harness-assumption`.** **The rule:** an oracle must not depend on a property the code does not enforce. Two ways to satisfy it here, either is fine: snapshot `nvim_buf_get_keymap` before `prep_chat`/`setup_markdown_keymaps` and treat the *diff* as parley's claims (no `desc` dependence at all), or make the convention real with an assertion that every `buffer_local` entry's `desc` contains the marker. Then add the documented feature-gated category to the closed list so a blessed map is not reported as a leak.

### Two universal claims are pinned over a hand-narrowed subset
`tests/unit/keybindings_spec.lua:472,501,513` and `tests/integration/keybinding_agreement_spec.lua:139`. README.md's "Every binding parley ships is rebindable **and** disableable" is pinned by "every registry entry can actually be disabled from config", which excludes every dotted `config_key` — 15 of 81 picker entries — via a hand-typed `not e.config_key:find(".")`. And the Done-when's "`:map` showing no parley mapping" is pinned only against `nvim_buf_get_keymap`; `nvim_get_keymap` is never consulted. Both underlying behaviours are in fact correct — I verified all 15 dotted entries disable via a nested config build (`stuck: {}`) and that globals add nothing with the switch off — so this is coverage, not a bug.

**This is the 4th finding in family `docs-assert-unverified-behavior`** (5th counting round 8's I1, which was lost to the protocol error). Round 8 stated the rule and this round applied it to the README-commands test while leaving two sibling instances. **The rule, restated:** a promise quantified over a set must be pinned by a test that *derives* the set from the source; a filter that removes members of that set is an allowlist wearing a predicate. **The enumeration:** build the nested table for dotted keys instead of skipping them, and assert the global keymap table alongside the buffer one. A third instance of the same rule is in-window at `tests/arch/single_source_sweeps_spec.lua:66-72`: the `000205` fallback's comment claims it "keeps its historical coverage rather than silently passing", but on `main` `git merge-base HEAD main` is `HEAD`, the diff is empty, and the guard passes vacuously.

### Leaving interview mode deletes the user's own global insert-mode `<CR>`
`lua/parley/interview.lua:94-99`. `remove_keymap` does an unconditional `vim.keymap.del("i", "<CR>")`. Measured: set a user map on `i <CR>`, call `setup_keymap()`, then `remove_keymap()` — the user's map is gone (`nil`), not restored. `<C-n>i` then `<C-n>I` destroys a cmp/blink user's accept key for the rest of the session. This is precisely the collision the Spec names ("colliding with cmp/blink, which nearly every Neovim user has on `<CR>`") and the Done-when's `<CR>` clause covers, and it is the one `<CR>` path M2 deliberately left alone; the carve-out reasoning at `config.lua:337` decides it is "the feature, not a default" but never asks whether *removing* it is safe. Note the code is outside the diff window — it is the operator's call whether this lands here, in M3, or at close.

**This is the 2nd finding in family `command-not-scoped-to-context`.** **The rule:** a keymap that serves a buffer-scoped feature must be installed buffer-locally; a global install makes teardown destructive because `del` cannot distinguish "mine" from "theirs". Buffer-local here also fixes it for free — parley's map shadows and then unshadows, and the user's global map resurfaces. The enumeration is small: `interview.setup_keymap` is the only global feature map left (`spell.attach` is already buffer-local at `spell.lua:172`).

### The milestone's new spec and module are absent from `atlas/traceability.yaml`
`atlas/traceability.yaml:689-696`. The `ui/keybindings` entry maps only `keybindings_spec.lua` and `config_tools_spec.lua`. Missing: `tests/integration/keybinding_agreement_spec.lua` (this milestone's headline guard), `lua/parley/branch_ref.lua` and `tests/unit/branch_ref_spec.lua` (zero occurrences of `branch_ref` in the file), and the `#214` arch guards. Concrete consequence: `make test-changed` after editing `atlas/ui/keybindings.md` — the doc this milestone rewrote — runs neither the agreement spec nor the new arch guards. Nothing enforces this index (no guard references `traceability.yaml`), which is why it drifted; M1's BR-2 flagged the same gap for `branch_ref` and only its test half was closed. Family: `artifact-missing-from-its-index`.

## 4. Minor findings

- `lua/parley/init.lua:3306` and `:4648` — `key_hint` is defined **twice, verbatim**, comment and all; it replaced a `primary` helper that was also duplicated at those two sites, so the fix preserved the duplication instead of retiring it. It is the only byte-identical duplicated local in `lua/` (measured). *(5th in `duplicate-helper-not-retired` — the rule: a helper needed at two call sites in one module is one module-scope helper; don't copy the body to keep the diff local.)*
- `lua/parley/issue_finder.lua:451` and `lua/parley/note_finder.lua:388-389` pass a possibly-nil `key_for` result straight to `string.format("%s")`, rendering `"Issues (open  nil: cycle view)"` / `"Note Files (3 months  nil/nil: cycle)"` under `default_keymaps = false`; `chat_finder.lua:634-635` guards the same value with `or "-"`. Same sweep, three sites, two conventions. Family `nullable-return-not-handled`.
- `tests/arch/single_source_sweeps_spec.lua:473` — `for line in read(path):gmatch("[^\n]*")` yields an empty match after every line, so reported line numbers are roughly doubled: my planted violation at `system_prompt_picker.lua:121` was reported as `:223`. Use `for line in (body.."\n"):gmatch("(.-)\n")`.
- `keybinding_registry.lua:1019` — a malformed `shortcut` (number, boolean) falls through `as_list` to `nil` and silently **disables** the binding rather than warning; before M2 it fell back to the default. *(2nd in `illegal-state-representable-in-signature` — the rule: parse the config value into a typed result at the boundary and degrade visibly, rather than mapping every unrepresentable shape onto a legal one.)*
- README's "Changed defaults (upgrading)" table omits that `shortcut = ""` changed meaning (fall-through → disable). Low blast radius, but it is a public config-contract change.
- `chat_shortcut_delete_file` is the one new user-facing config key this round adds that neither README nor `atlas/ui/keybindings.md` mentions. Rather than adding it by hand, consider deleting the README's per-knob list entirely — the file already says `config.lua` is the reference.

## 5. Test coverage notes

- Four independent reversions all went red; these guards are load-bearing, not decorative.
- The agreement spec now covers chat, markdown and journal-sidecar buffers. Remaining uncovered scopes: `note`, `issue`, `vision`, `repo`, and every `*_finder` scope. Pickers were the site of C1's other half and now have **no** test at all — no assertion that a picker key honours a rebind, `shortcut = ""`, or the master switch. I verified manually that `chat_finder.open()` and `issue_finder.open()` don't raise with the switch off, but nothing in the suite does.
- No test observes global keymaps. Combined with the desc-based oracle, the suite's view of "what parley bound" is narrower than the claims it certifies.
- `tests/unit/keybindings_spec.lua:558` (`help shows no key that is not bound`) matches with `^%s%s(%S+)%s%s`, which silently skips any line whose key reaches the 12-column pad. No shipped key does today (`<C-g><C-g>` is 10), so the assertion is fully effective — but it will go quietly partial the first time a longer key ships.

## 6. Architectural notes

- **ARCH-DRY — flag (Minor).** Large net win: ~23 ungoverned `config.X.shortcut` reads collapsed onto one resolver, enforced by a guard I verified red. The one regression is `key_hint` duplicated verbatim in the same module.
- **ARCH-PURE — pass.** `resolve_keys`, `help_lines`, `opt_in`, `native_overrides` are pure and unit-tested without IO; `registry_callbacks`, `native_map`, `register_buffer` are thin seams. Returning callbacks for the registry to install is the right inversion and is the part of this diff that will age best.
- **ARCH-PURPOSE — pass on the sweep.** I ran the shadow-sweep independently: 0 `.shortcut` reads and 0 `.modes` reads outside the registry across 147 files; no `plugin/`, `ftplugin/` or `scripts/` consumer exists. This is the class, not the instance. Flag only on the disable claim being *proven* for 66 of 81.
- **ARCH-MOCK — N/A** for external services. Note the arch guards shell to `git` and degrade to `pending()` or a `000205` fallback rather than failing, so guard strength varies with checkout state (see the third instance under the docs finding).
- **ARCH-CONSTRAINTS — pass, with a win.** No new per-keystroke work; gating typeahead removes a `TextChangedI` autocmd and an insert-mode `<CR>` map from every chat buffer by default. `key_for` linear-scans `M.entries` while `M._by_id` sits unused beside it — 81 entries, so irrelevant, but it is free to fix.
- **ARCH-SECURE — N/A** for untrusted input and credentials. One note under Minor: a malformed config value degrades invisibly rather than loudly.
- **ARCH-ORDER — flag.** `default_keymaps` is sampled at three sites and the reversibility rule is written for one of them; `_explicit_shortcuts` is derived state stored on the public config table with no invariant tying it to the `opts` it came from. The buffer-side ordering is now honestly documented and tested in both directions — that part is done well.

## 7. Plan revision recommendations

1. **`## Revisions` — "master switch extent, as built."** Record that the switch is sampled per-`setup()` for global maps with no teardown, and per-buffer for buffer-local ones guarded by `_prepared_bufs`. The `config.lua:340` sentence and the atlas paragraph currently describe only the second. State which of the two the Done-when's `:map` criterion is certified against.
2. **`## Revisions` — "disableability proven for 66 of 81 entries."** The Done-when says "Every binding parley registers is rebindable and disableable through config". The assertion excludes the 15 dotted picker entries. Either record the narrowing or widen the test; do not leave the Done-when claiming the wider set.
3. **`## Revisions` — "insert-mode `<CR>`: typeahead gated, interview left as-is."** The Done-when covers "insert-mode `<CR>`" without qualification; M2 delivered the typeahead half. Record the interview half's disposition explicitly — including that its teardown currently deletes the user's own map — and assign it to M3 or to close.
4. **Update `atlas/traceability.yaml`'s `ui/keybindings` entry** to list `tests/integration/keybinding_agreement_spec.lua`, `lua/parley/branch_ref.lua` and `tests/unit/branch_ref_spec.lua`. This retires the surviving half of M1's BR-2.

```findings
findings:
  - id: new
    severity: Important
    family: no-seam-for-ordering
    title: |
      default_keymaps = false does not revoke global maps installed by an earlier setup()
    detail: |
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
  - id: new
    severity: Important
    family: test-harness-assumption
    title: |
      the no-leaks guard detects parley maps by a desc convention nothing enforces
    detail: |
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
  - id: new
    severity: Important
    family: docs-assert-unverified-behavior
    title: |
      "every binding disableable" and ":map shows no parley mapping" are pinned over hand-narrowed subsets
    detail: |
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
  - id: new
    severity: Important
    family: command-not-scoped-to-context
    title: |
      leaving interview mode deletes the user's own global insert-mode <CR> map
    detail: |
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
  - id: new
    severity: Important
    family: artifact-missing-from-its-index
    title: |
      the milestone's headline spec and M1's pure module are absent from atlas/traceability.yaml
    detail: |
      atlas/traceability.yaml:689-696 maps ui/keybindings to keybindings_spec.lua and
      config_tools_spec.lua only. Missing: tests/integration/keybinding_agreement_spec.lua,
      lua/parley/branch_ref.lua and tests/unit/branch_ref_spec.lua (zero occurrences of
      "branch_ref" in the file), and the new #214 arch guards. Consequence: make
      test-changed after editing atlas/ui/keybindings.md — the doc this milestone rewrote —
      runs neither the agreement spec nor the new guards. No guard references
      traceability.yaml, which is why it drifts; M1's BR-2 flagged the same gap and only
      its test half was closed.
  - id: new
    severity: Minor
    family: duplicate-helper-not-retired
    title: |
      key_hint is defined twice verbatim in init.lua
    detail: |
      init.lua:3306 and init.lua:4648 carry identical bodies and identical five-line
      comments. It replaced a `primary` helper that was also duplicated at those two sites,
      so the fix preserved the duplication rather than retiring it. Measured: the only
      byte-identical duplicated local in lua/. 5th in family. Rule: a helper needed at two
      call sites in one module is one module-scope helper; do not copy the body to keep the
      diff local.
  - id: new
    severity: Minor
    family: nullable-return-not-handled
    title: |
      key_for's new nil return reaches string.format at two of three picker title sites
    detail: |
      issue_finder.lua:451 and note_finder.lua:388-389 pass a possibly-nil key straight to
      string.format("%s"), rendering "Issues (open  nil: cycle view)" and "Note Files
      (3 months  nil/nil: cycle)" under default_keymaps = false. chat_finder.lua:634-635
      guards the same value with `or "-"`. Same sweep, three sites, two conventions. Rule:
      when a helper's return type gains nil, every consumer must be updated, not only the
      ones that would crash.
  - id: new
    severity: Minor
    family: diagnostic-cites-wrong-location
    title: |
      the new arch guard reports roughly doubled line numbers
    detail: |
      single_source_sweeps_spec.lua:473 iterates with gmatch("[^\n]*"), which yields an
      empty match after every line. Measured: a planted violation at
      system_prompt_picker.lua:121 was reported as :223. Use
      for line in (body.."\n"):gmatch("(.-)\n").
  - id: new
    severity: Minor
    family: illegal-state-representable-in-signature
    title: |
      a malformed shortcut value silently disables the binding
    detail: |
      keybinding_registry.lua:1019 — shortcut = 5 or shortcut = true falls through as_list
      to nil and disables the entry; before M2 it fell back to default_key. 2nd in family.
      Rule: parse the config value into a typed result at the boundary and degrade visibly
      (log and fall back), rather than mapping every unrepresentable shape onto a legal one.
      Related surface gaps, same round: README's "Changed defaults (upgrading)" table omits
      that shortcut = "" changed meaning from fall-through to disable, and
      chat_shortcut_delete_file is the one new config key neither README nor
      atlas/ui/keybindings.md mentions.
```
