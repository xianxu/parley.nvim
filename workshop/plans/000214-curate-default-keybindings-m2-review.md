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

---

## Re-review — 2026-09-07T15:29:49-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | b17f4761101430bea7ed5780b240b8f8e18e8ab9..a84108a177816c0e5dc16dae9b92a7775e0df276 |
| command | sdlc milestone-close --issue 214 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-07T15:29:49-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

All nine open findings are genuinely fixed, and I verified seven of them the hard way — reverting the fix in place and watching a named test go red, or planting the exact failure the guard exists to catch. `make test` is green (198 spec files, exit 0; luacheck 0 warnings / 0 errors across 352 files). The round's headline work is sound: `register_global` now tracks and revokes what it installed, the leak oracle no longer depends on a `desc` convention (I planted a desc-less `vim.keymap.set` in `prep_chat` and five tests went red), the disable/rebind claims are quantified over all 81 entries including the 15 dotted picker keys, and the traceability guard is self-enforcing. What keeps this from SHIP is that three of the round's own fixes introduced new behaviour nobody measured: the interview `<CR>` rescope destroys parley's *own* spell-typeahead `<CR>` and confines interview-mode timestamping to one buffer (both measured); the malformed-shortcut warning fires a `vim.notify` plus a log-file append on every buffer prep and every `<C-g>?` rather than parsing once at the boundary, inside an entity the plan lists as PURE; and the README paragraph that replaced the per-knob list makes a universal claim that is false for 2 of 81 knobs. None is a crash, none blocks the gate — but the first is a functional regression shipped by a milestone whose Plan declares itself behaviour-free.

## 1. Strengths

- **Every claimed fix is pinned, and I confirmed it by reversion.** Removing `revoke_global_maps()` reds two tests; removing the `desc` guard reds a third; reverting interview to a global map reds two; forcing dotted config lookups to `nil` reds both the disable and rebind loops; reverting the malformed-shortcut branch reds two; dropping `keybinding_agreement_spec.lua` from `traceability.yaml` reds the new guard. Seven independent reversions, seven red suites.
- **The new leak oracle is measurably stronger, not just differently worded.** `tests/integration/keybinding_agreement_spec.lua:63-72` diffs a pre-prep snapshot instead of filtering on `desc`. I planted `vim.keymap.set("n", "<C-g>ZZ", …, { buffer = buf })` with **no desc** immediately after `_prepared_bufs[buf] = true` — the exact case BR-39 named as invisible — and five tests failed. The comment at `:79-82` explaining *why the snapshot must precede the prep* is the transferable part.
- **`register_global`'s revocation gets the ownership rule right** (`keybinding_registry.lua:1223-1231`): it deletes only maps whose current `desc` still matches what it installed, so a key the user rebound after `setup()` survives. Both halves are asserted separately (`:480`, `:498`), and both go red when reverted.
- **The atlas states the rule for all three sample sites**, not the one that was examined (`atlas/ui/keybindings.md`, "Reversibility, per sample site"). That table is the shape BR-38 asked for — it makes the next reader check the third site instead of rediscovering it.
- **The traceability guard immediately earned its keep** — it is red-verifiable, and per the commit it found a second unrouted spec from M1 on its first run. A guard that finds something you did not already know is the good kind.

## 2. Critical findings

None.

## 3. Important findings

### A — the interview `<CR>` rescope destroys parley's own spell map, and confines interview mode to one buffer

`lua/parley/interview.lua:95-118`. Both measured, in a probe spec run against HEAD:

```
after spell.attach:      { "parley: accept spell suggestion / newline" }
after interview install: { "Insert timestamp on new line in interview mode" }   -- spell's map is gone
after interview remove:  { }                                                     -- and so is the slot
```

```
b1 (entered here) = { "Insert timestamp on new line in interview mode" }
b2 (opened after) = { }        -- mode flag, timer and lualine still say "on"
```

Two consequences. (1) `<C-n>i` then `<C-n>I` in a chat buffer with `chat_spell = { typeahead = true }` leaves that buffer with **no** `<CR>` map at all — spell typeahead is dead there for the buffer's lifetime. The same happens to a user's *buffer-local* `<CR>` (nvim-autopairs and some cmp setups install one). (2) `interview_start`/`interview_stop` are `scope = "note"` with no `buffer_local`, so they are **global** maps: interview mode is session state, but its effect is now installed on exactly one buffer. Open a second note while the mode is on and `<CR>` silently stops inserting timestamps while the statusline still reports interview mode active. That is a behaviour change to a shipped feature, inside the milestone whose Plan says "M2 is pure policy … This is behaviour" — and no `## Revisions` entry records it. The `## Core concepts` row claims "it shadows and unshadows instead of destroying", which is true against a global map and false against the buffer-local map it now collides with.

> **This is the 3rd finding in family `command-not-scoped-to-context`.** Do not just special-case spell. **The rule, in full:** `del` cannot distinguish "mine" from "theirs" *at any scope* — narrowing from global to buffer-local moved the collision, it did not remove it. A feature map must (a) be installed at the same scope as the state it serves, and (b) tear down by **restoring what it shadowed**, not by deleting the slot: capture `vim.fn.maparg(lhs, mode, false, true)` before setting and re-apply it after, or route both features through one owned `<CR>` dispatcher the way `base_cr` already does for spell. **The enumeration is three collisions on one slot:** interview `<CR>` vs spell's buffer-local `<CR>` (measured, destructive), interview `<CR>` vs a user's buffer-local `<CR>` (same mechanism), and interview's global mode flag vs its per-buffer effect (measured, silent). If the operator wants the scope narrowing kept, it needs a Done-when/Revisions entry saying interview mode is now buffer-scoped, and a test over two buffers.

### B — the README paragraph that replaced the per-knob list is false for 2 of 81 knobs

`README.md:275-277`: "Every knob is named in `lua/parley/config.lua` beside the binding it controls — that file is the reference, so this section does not duplicate the list." Enumerated all 81 `config_key`s against `lua/parley/config.lua`: **`global_shortcut_vision_allocation`** and **`agent_picker_mappings.expand_catalog`** appear nowhere in that file (`grep` confirms zero hits outside `keybinding_registry.lua`). Both still resolve from `default_key` and are overridable, so this is discoverability, not breakage — but the round deleted an explicit list and replaced it with a stronger universal claim that nothing derives.

> **This is the 5th finding in family `docs-assert-unverified-behavior`.** Do not add the two knobs by hand. **The rule, restated for the fourth time:** a user-facing promise quantified over a set must be pinned by a test that *derives* the set from the source. **The enumeration is one loop** — for each `reg.entries[i].config_key`, assert it appears in `lua/parley/config.lua` (for a dotted key, the table and the leaf) — and it belongs next to the "commands the README names" test, which is already the correct shape. The family has now produced five findings across four rounds and still has no derived assertion for the README's *prose* claims specifically; that is the thing to fix, not the two knobs.

### C — the malformed-shortcut warning fires at every resolution, not once at the boundary

`lua/parley/keybinding_registry.lua:995-1004`. `parley.logger.warning` opens the log file for append, writes, closes, and schedules a `vim.notify` popup (`logger.lua:88-101`). Measured with `chat_shortcut_respond = { shortcut = 5 }`:

```
help_lines("chat")  → 1 warning   (twice in a row → 2)
register_buffer(…)  → 1 warning   (i.e. once per chat/markdown buffer prepared)
```

So one typo produces a "Parley.nvim: …" popup on **every BufEnter of a chat buffer** and **every `<C-g>?` press**, for the whole session. Two problems ride together: the issue's `## Core concepts` lists `resolve_keys` under **Pure entities**, and it now performs file IO and a UI notification (`ARCH-PURE`); and repeated notify + file-append on the buffer-prep path is exactly the "repeated expensive work on a UI path" `ARCH-CONSTRAINTS` names.

> **This is the 3rd finding in family `illegal-state-representable-in-signature`.** The finding that produced this fix stated the rule itself: "**parse the config value into a typed result at the boundary** and degrade visibly." The fix validates at every *read* instead. **The rule:** validation belongs where the config enters the system — `setup()`, beside the `_explicit_shortcuts` capture that already walks the same tables — and the resolver stays a total function of already-typed input. **The enumeration:** every config shape `resolve_keys` currently tolerates by coercion (number/boolean `shortcut`, a non-table `cfg_val` for a dotted key, a list containing non-strings — that last one is still silently filtered at `:1008`) should be reported once at `setup()` and normalised there, leaving `resolve_keys` with no logger dependency at all.

### D — two of this round's oracles still trust an input the code does not verify

Both measured.

1. `tests/integration/keybinding_agreement_spec.lua:474` — "a fresh setup with the switch off installs no global map" is not fresh. Its `before = global_snapshot()` runs after ~13 earlier `setup()` calls in the same file, so anything `setup()` installs globally *outside* the registry is already in the baseline. I planted `vim.keymap.set("n", "<C-g>ZQ", …, { desc = "planted global" })` immediately before the `register_global` call: the whole file stayed **green**. The identical assertion in an isolated spec goes red on the same plant. The spec's own comment at `:79-82` states this rule correctly for buffers and the global block violates it.
2. `keybinding_registry.lua:1080-1090` — `feature_gated` is trusted by both leak tests (`:129`, `:151`) with nothing asserting its members are actually gated or carry a rationale. `native_overrides` has both guards (`single_source_sweeps_spec.lua:546,558`); `feature_gated` has neither, and the "really absent until the feature is on" check at `:161` hand-types `<CR>` instead of iterating the table. Adding a key here silently widens the allowance list. (Related, same shape: the new traceability guard at `:588` keys off `git merge-base HEAD main`, so on `main` it passes vacuously — the exact thing the `000205` fallback was fixed for two hunks earlier, where the answer was `pending()`.)

> **This is the 3rd finding in family `test-harness-assumption`.** **The rule:** an oracle has two unverified inputs — its *baseline* and its *allowance list* — and each must be derived from a state the subject has not touched, or asserted. **The enumeration:** take the global baseline in a `before_each`/fresh process the way the buffer fixtures do; give `feature_gated` the two guards `native_overrides` already has (every member carries `gate`+`where`; every member really resolves to nothing under the shipped config); and make the branch-scoped traceability guard say `pending` off a branch rather than passing on an empty diff.

## 4. Minor findings

- `lua/parley/init.lua:2284-2285` and `lua/parley/spell.lua:167-169` still describe interview's `<CR>` as a **global** map that spell's buffer-local map "shadows". After BR-41 both are buffer-local on the same buffer and neither shadows the other — the later install wins outright, which is finding A. *(3rd in `stale-comment-after-move` — the rule: a comment that explains *why* a mechanism is safe must be re-read when the mechanism moves; the two here are the load-bearing explanation for `base_cr` existing at all.)*
- `tests/integration/keybinding_agreement_spec.lua:124-136`, `:146-158`, `:318-328` — three near-identical "build `known` from entries + `native_overrides` (+ `feature_gated`) then diff" blocks. *(6th in `duplicate-helper-not-retired`. The family is now six deep with the rule stated each time and no enforcement; a guard over byte-identical adjacent blocks, or simply a `known_keys(cfg)` local in this spec, is the class fix.)*
- `README.md:275` — the "Every knob is named in `config.lua`…" paragraph has no blank line before it, so GFM renders it as a lazy continuation of the preceding `u`/`<C-r>` bullet rather than as its own paragraph.
- `keybinding_registry.lua:1008` — a `shortcut` list containing a non-string still drops that element silently, which is the same "typo indistinguishable from a decision" the number/boolean case was just fixed for.

## 5. Test coverage notes

- Seven of nine claimed fixes verified red by reversion or by planting the failure; the two exceptions are pure moves. **BR-43** (`key_hint` deduplication) and **BR-44** (`key_label`) are both unpinned: reverting `key_label` leaves `chat_finder_logic_spec.lua:1009` and `note_finder_logic_spec.lua:239` green, because they assert the default-config rendering and never the `default_keymaps = false` case that produced `nil`. Both fixes are correct and I confirmed them by reading the resolution path, but neither would survive a regression.
- The 81-entry disable/rebind loops and the derived help↔reality assertions are the strongest coverage in the milestone: they are quantified over the registry with no filters left.
- Still uncovered by the agreement spec: the `note`, `issue`, `vision`, `repo` and `*_finder` scopes, and the picker keymaps generally. Finding A's whole surface (interview + spell on one buffer) has no test; the two BR-41 tests exercise a bare scratch buffer with no spell attached.

## 6. Architectural notes

- **ARCH-DRY — flag (Minor).** Three duplicated known-set/diff blocks in the agreement spec; sixth instance of the family.
- **ARCH-PURE — flag (C).** `resolve_keys`, declared a Pure entity, now does `io.open`+write and schedules `vim.notify` on the malformed path. Move the parse to `setup()`.
- **ARCH-PURPOSE — flag (A, B).** BR-41 was answered at the site it named (a global `del`) and not at the class (`del` on any slot you don't exclusively own); BR-46's README half was answered by replacing a list with a broader unverified claim. The shadow-sweep for "every knob is in config.lua" is two knobs short.
- **ARCH-MOCK — pass / N/A.** No external binary or service in the window; the tests drive real Neovim keymap APIs at the correct seam, which is the right boundary for this work.
- **ARCH-CONSTRAINTS — flag (C).** Repeated notify + file append on the buffer-prep and help-render paths. Otherwise clean: the master switch is an O(1) early return in `resolve_keys`, and `revoke_global_maps` is one `maparg` per previously-installed map at `setup()` only.
- **ARCH-SECURE — pass.** No credentials or externally-authored input in the window. Positive note: `revoke_global_maps` compares `desc` before deleting rather than deleting blind, which is the right trust boundary between parley's claims and the user's.
- **ARCH-ORDER — flag (A).** `_parley._state.interview_mode` (session-global, plus a timer and a lualine indicator) and `interview._keymap_bufs` (per-buffer) are now two pieces of state for one mode, with the legal combinations unwritten: "mode on, zero mapped buffers" and "mode on, mapped buffer no longer displayed" are both reachable and undefined. The events that matter here are the ones the caller cannot block — a `BufEnter` on a second note while the mode is on, and a buffer wipe of the entering buffer. Write the `(state, event) -> (state, effects)` row for those two, or scope the mode flag to the buffer so there is only one piece of state.

## 7. Plan revision recommendations

1. **`## Revisions` — "interview mode is buffer-scoped as of M2."** Record that `setup_keymap` moved from a global to a buffer-local map, that this narrows the mode's effect to the buffer where it was entered while the flag/timer/statusline stay global, and that it collides destructively with `chat_spell.typeahead`'s `<CR>` on the same buffer. The `## Core concepts` row currently says "it shadows and unshadows instead of destroying", which is true against a global map and false against the buffer-local one; amend it.
2. **`## Core concepts` — `resolve_keys` is no longer purely pure.** Either move the malformed-value warning to `setup()` and keep the Pure-entities row honest, or move `resolve_keys` out of that table and say what IO it performs. As written the table and the code disagree.
3. **`## Revisions` — record that M2 landed two behaviour changes.** The Plan's "Why M3 and not M2" paragraph argues M2 is pure policy and that bundling behaviour into a curation milestone is what cost M1 five rounds. BR-41 (interview `<CR>`) and BR-46 (malformed shortcut now warns and falls back rather than disabling) are both behaviour, both landed here with operator sign-off on the first. Say so, so the paragraph stops asserting something the milestone no longer satisfies.

```findings
dispose:
  - id: BR-38
    disposition: addressed
    note: |
      Verified red twice by reversion — removing revoke_global_maps() fails two switch tests; removing the desc guard fails the "user rebound" test.
  - id: BR-39
    disposition: addressed
    note: |
      Planted a desc-less vim.keymap.set in prep_chat: five tests red. Emptying feature_gated reds the typeahead-on leak test.
  - id: BR-40
    disposition: addressed
    note: |
      Forcing dotted config lookups to nil reds both the disable and rebind loops over all 81 entries; the 000205 fallback now reports pending instead of passing vacuously.
  - id: BR-41
    disposition: addressed
    note: |
      Verified red by reverting to the global map — but the rescope introduced two new collisions, raised as a new finding in the same family.
  - id: BR-42
    disposition: addressed
    note: |
      Removing keybinding_agreement_spec.lua from traceability.yaml reds the new guard; branch_ref module and specs are routed.
  - id: BR-43
    disposition: addressed
    note: |
      One module-scope key_hint at init.lua:1527. Unpinned (a pure move); the family still has no enforcement — see Minor.
  - id: BR-44
    disposition: addressed
    note: |
      Three title sites now use key_label. No test pins the "-" fallback: the existing title specs stay green if reverted.
  - id: BR-45
    disposition: addressed
    note: |
      Verified — a planted .shortcut read at system_prompt_picker.lua:121 is now reported as :121, not :223.
  - id: BR-46
    disposition: addressed
    note: |
      Verified red by reverting the malformed branch — but the warning fires at every resolution rather than at the boundary; see new finding.
findings:
  - id: new
    severity: Important
    family: command-not-scoped-to-context
    title: |
      the interview <CR> rescope destroys parley's own spell map and confines interview mode to one buffer
    detail: |
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
  - id: new
    severity: Important
    family: docs-assert-unverified-behavior
    title: |
      README's "every knob is named in config.lua" is false for 2 of 81 knobs
    detail: |
      README.md:275-277 replaced the per-knob list with a universal claim. Enumerated all 81
      config_keys against lua/parley/config.lua — global_shortcut_vision_allocation and
      agent_picker_mappings.expand_catalog appear nowhere in that file (zero grep hits outside
      keybinding_registry.lua). Both still resolve from default_key, so this is
      discoverability, not breakage. 5th in family across four rounds. Rule restated: a
      user-facing promise quantified over a set must be pinned by a test that DERIVES the set
      from the source. Enumeration is one loop beside the existing "commands the README names"
      test — for each entry, assert its config_key appears in config.lua (table plus leaf for
      a dotted key). Fix the missing derived assertion, not the two knobs.
  - id: new
    severity: Important
    family: illegal-state-representable-in-signature
    title: |
      the malformed-shortcut warning fires at every resolution instead of parsing once at the boundary
    detail: |
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
  - id: new
    severity: Important
    family: test-harness-assumption
    title: |
      two of this round's oracles still trust an input the code does not verify
    detail: |
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
  - id: new
    severity: Minor
    family: stale-comment-after-move
    title: |
      init.lua and spell.lua still describe interview's <CR> as a global map
    detail: |
      init.lua:2284-2285 and spell.lua:167-169 both say spell's buffer-local map "shadows
      interview's global <CR> map", which is the load-bearing explanation for base_cr existing
      at all. After BR-41 both maps are buffer-local on the same buffer and neither shadows the
      other. 3rd in family. Rule: a comment that explains why a mechanism is SAFE must be
      re-read when the mechanism moves.
  - id: new
    severity: Minor
    family: duplicate-helper-not-retired
    title: |
      three near-identical known-set/diff blocks in the agreement spec
    detail: |
      keybinding_agreement_spec.lua:124-136, :146-158 and :318-328 each rebuild `known` from
      reg.entries plus native_overrides (plus feature_gated in two of the three) and then diff.
      6th in family; the rule has been stated each round and there is still no enforcement. A
      known_keys(cfg) local in this spec is the cheap fix, a guard over duplicated adjacent
      blocks is the class fix.
```

---

## Re-review — 2026-09-07T16:15:14-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | b17f4761101430bea7ed5780b240b8f8e18e8ab9..5bc1a4192d2718ed013acd070bbe0bf37e94c3d3 |
| command | sdlc milestone-close --issue 214 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-07T16:15:14-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M2's substance is delivered and, unusually for this issue, most of it is genuinely load-bearing: all 81 registry entries carry a `config_key`, `resolve_keys` is the only path from config to a key (enforced by an arch guard that I confirmed has no escapes left in `lua/`), and the round-10 fixes hold up under reversion — I reverted the interview restore and got 3 red, simulated round 9's buffer-local shape and got the 3 tests BR-47 named, planted a global leak inside `register_global` and got 3 red, removed the two missing config knobs and got the BR-48 guard red, and unrouted the new spec on a real branch and got the traceability guard red. Full suite green (`make test`, exit 0, lint included). What keeps this from SHIP is not the code — it is that round 10 reversed round 9's design and swept the code and the issue but not the two artifacts round 9 wrote to *teach* that design: `atlas/ui/keybindings.md` still says interview's `<CR>` is buffer-local, and `workshop/lessons.md` still carries "feature-scoped keymaps go on the buffer, never globally" as a rule — the exact instruction that produced BR-47. Separately, the six new interview tests drive `setup_keymap`/`remove_keymap` directly and never `enter()`/`exit()`; driving the real transition raises `Cannot deepcopy object of type userdata` from `prep_chat`, so the state the round's rationale is built on ("the map lives at the same scope as the session state it serves") cannot currently be exercised end-to-end.

## 1. Strengths

- **The single-source sweep is enforced, not asserted once.** `tests/arch/single_source_sweeps_spec.lua:477` forbids any `.shortcut` read outside the registry; the only survivors in `lua/` are five explicitly-annotated `shortcut-read-ok` lines in `setup()`, each doing intent-detection or validation rather than key derivation. This is the C1 class fix actually closing.
- **BR-47's fix is pinned in both directions.** Reverting the restore reds "a pre-existing global `<CR>` is restored", "a user's Lua-callback `<CR>` survives", "re-entering does not save our own map"; re-applying round 9's buffer-local shape reds "spell typeahead's buffer-local `<CR>` is untouched" and "the mapping applies in every buffer". Both halves of the finding have their own oracle (`keybinding_agreement_spec.lua:473,495`).
- **BR-50's baseline fix is structural, not a patch.** `PRISTINE_GLOBALS` at `keybinding_agreement_spec.lua:69` is captured at module load; the reviewer's `<C-g>ZQ` plant now reds three tests instead of passing.
- **BR-49's headline is closed with a negative assertion.** `keybindings_spec.lua` asserts `keybinding_registry.lua` contains no `parley.logger` reference at all — a guard that survives refactoring, not a call-count check.
- **The malformed-shortcut fix degrades to the default rather than to nothing** (`init.lua:636-670` strips, `resolve_keys` falls back), and `setup()` is asserted to warn exactly once across 3 `help_lines` + 5 `resolve_keys` calls.

## 2. Critical findings

None.

## 3. Important findings

### N1 — the artifacts that teach the interview design still teach the reversed one

`atlas/ui/keybindings.md:130-134` and `workshop/lessons.md:1435`.

The atlas says "Interview's `<CR>` is **buffer-local** … `del` cannot tell 'mine' from 'theirs', so it must never be aimed at a global map." The shipped map is global (`interview.lua:112`), and round 10's own commit message says the opposite: "the defect BR-41 named is teardown, not scope. `vim.keymap.del` cannot tell 'mine' from 'theirs' at **ANY** scope." `lessons.md` rule 5 is worse than stale — it is a directive ("Feature-scoped keymaps go on the buffer, never globally") that AGENTS.md §4 has every agent read at session start, and following it re-creates BR-47 exactly.

> **This is the 4th finding in family `stale-comment-after-move`.** Do not just edit the two paragraphs. **The rule:** when a round reverses a prior round's decision, the artifacts that *recorded* that decision are part of the reversal's diff — and they are mechanically enumerable, not a memory exercise: `git show --stat <the reversed commit>` lists them. Here `a84108a` touched `atlas/ui/keybindings.md`, `workshop/lessons.md`, `lua/parley/interview.lua` and the issue file to describe the buffer-local design; `5bc1a41` touched the last two and neither of the first two. **The enumeration for this round:** the atlas paragraph, the lessons rule, and a `## Revisions`/`## Log` entry on the issue recording the reversal (AGENTS.md §1 says append, don't overwrite — the Core-concepts bullet was rewritten in place and there is no Log entry for round 9 or round 10 at all).

### N2 — the interview tests exercise the sub-step, not the transition, and the transition raises

`tests/integration/keybinding_agreement_spec.lua:420-508` calls `interview.setup_keymap()` / `interview.remove_keymap()` directly. The production transitions are `interview.enter()` / `interview.exit()`, which also drive `_state.interview_mode` and `_state.interview_timer`. Driving those instead surfaces a hard error, measured through the real `BufEnter` path:

```
interview.enter()            -- <C-n>i
:edit <a chat file>          -- BufEnter -> prep_chat -> refresh_state
E5108: vim/shared.lua:0: Cannot deepcopy object of type userdata
  ./lua/parley/init.lua:1347: in function 'refresh_state'
  ./lua/parley/init.lua:2310: in function 'prep_chat'
  ./lua/parley/highlighter.lua:1064  (BufEnter)
```

`start_timer` stores a `vim.loop` handle in `_state.interview_timer` (`interview.lua:193`); `refresh_state` deepcopies `_state` (`init.lua:1347`). So while interview mode is on, opening any chat file — and every other `refresh_state` caller: the agent picker, the web-search toggle, `ChatMove` — raises. **This is pre-existing** (the deepcopy predates the review base by ~16 months) and outside the diff window, so it should not block the gate on its own. It matters here because round 10's stated rationale is "the map must live at the same scope as the session state it serves," and that session state's own lifecycle cannot currently run; and because the tests added this round are the ones that would have found it.

> **This is the 4th finding in family `no-seam-for-ordering`.** Do not add a single regression test for the deepcopy. **The rule:** a lifecycle fix must be pinned through the transition a user actually triggers, not through the internal step the fix edited — the step in isolation cannot observe the state the transition carries. **The enumeration:** convert the six tests at `:435-508` to drive `interview.enter()` / `interview.exit()` (both work headless; I ran them), which surfaces this immediately, and keep the timer out of `_state` (or exclude it from the deepcopy) so the transition is runnable.

### N3 — BR-49 (re-raised): the boundary parse covers two of the four shapes the finding enumerated

`lua/parley/keybinding_registry.lua:998-1001`. The headline is fixed: the report moved to `setup()`, fires once, and the registry is asserted logger-free. But `bad_shape` at `init.lua:640` only rejects non-string/non-table, so the element-level coercion inside `as_list` is untouched. Measured:

```
shortcut = { 5 }            -> nil      -- silently DISABLED, same as shortcut = ""
shortcut = { "<M-z>", 5 }   -> {"<M-z>"} -- second key silently dropped
a.b = 5 (dotted, non-table) -> falls back to default_key, unreported
```

The first is the defect BR-46 was closed for — a typo and a deliberate disable producing the same outcome — surviving in a shape the boundary check does not look at. See §7 for what BR-49's own enumeration asked for.

## 4. Minor findings

- `lua/parley/init.lua:546` — `_explicit_shortcuts` is built from the raw `opts` ~90 lines *before* the malformed-shortcut strip at `:636`, so a knob whose value is later stripped is still marked "explicit". Measured: `default_keymaps = false` + `chat_shortcut_respond = { shortcut = 5 }` binds `<C-g><C-g>` — the master switch hands back a default key on a config that asked for none. Build the explicit set from the normalised config, or clear the entry when stripping. *(new family `derive-before-validate`: a derived fact computed from raw input before the boundary normalises it will disagree with the normalised value.)*
- `tests/integration/keybinding_agreement_spec.lua:526` — the BR-48 guard tests `shipped_src:find(leaf, 1, true)`, an unanchored substring. For 8 of the 15 dotted `config_key`s the leaf occurs elsewhere in `config.lua` (`delete` × 11, `move` × 7, `next_recency` × 3), so deleting those knobs leaves the test green. *(5th in `test-does-not-pin-the-fix` — the rule: a derived assertion must be **member-discriminating**; verify it by deleting one member at a time, for every member, not for the two the finding named. Match the leaf as an assignment, e.g. `%f[%w]<leaf>%s*=`.)*
- `README.md:277` — "Every knob is named in `lua/parley/config.lua`…" has no blank line before it, so GFM lazy continuation folds this section-level claim into the preceding `u`/`<C-r>` bullet. *(new family `markdown-block-not-separated`.)*
- Picker sites now use `key_for`, which returns only `keys[1]`; a user who configures a picker knob with a key **list** silently loses everything past the first. No picker entry ships a list today, so this is latent — but the same shrink hazard PQ-1 named, one seam over.

## 5. Test coverage notes

- Verified red by reversion this round: the interview restore (3 red), round 9's buffer-local shape (3 red), the global-leak plant (3 red), the BR-48 config knobs (1 red), the traceability route (1 red, on a real branch — the guard is not vacuous here). Those five are load-bearing.
- `feature_gated` now has both guards `native_overrides` has (`single_source_sweeps_spec.lua:554,564`). The runtime counterpart at `keybinding_agreement_spec.lua:178` still hand-types `<CR>` rather than iterating the table, so a second member would get resolver-level coverage but no buffer-level coverage. Cheap to close alongside BR-52.
- No test drives `interview.enter()`/`exit()` anywhere in the suite (N2).
- The leak/ghost machinery now covers chat *and* markdown buffers; `note`, `issue`, `vision`, `repo` scopes remain unexercised at the buffer level.

## 6. Architectural notes

- **ARCH-DRY — flag (BR-52).** The raw-`.shortcut` duplication is genuinely gone and guarded. The remaining instance is in the spec itself: three near-identical `known`-set/diff blocks at `keybinding_agreement_spec.lua:141-146`, `:163-168`, `:334-338`, untouched this round.
- **ARCH-PURE — pass.** `resolve_keys` is now a total pure function of `(entry, config)` with the logger dependency removed and *asserted* removed; `opt_in`/`native_overrides`/`feature_gated` are pure data; `native_map`, `mapset` restore and the typeahead gate are thin seams. This is the part of the diff that will age well.
- **ARCH-PURPOSE — flag (N3).** The shadow-sweep the last round demanded is complete at the install seam — every consumer derives, and a guard keeps it that way. The remaining gap is BR-49's own enumeration: the finding named four coercion shapes and the fix reports two.
- **ARCH-MOCK — N/A.** No external binary or service in the production path. The arch guards shell out to `git`, and degrade to a reporting `pending()` rather than a silent pass.
- **ARCH-CONSTRAINTS — pass, with a win.** Moving validation to `setup()` removes a `vim.notify` + log append from every chat/markdown `BufEnter`; the master switch is an O(1) early return; `revoke_global_maps` runs once per `setup()` over ~43 tracked maps.
- **ARCH-SECURE — N/A** for untrusted input and credentials. `mapset` restores a dict produced by `nvim_get_keymap` in this same process; `native_map` now logs and skips rather than `error()`-ing on a user's buffer.
- **ARCH-ORDER — flag (N2, and the Minor above).** The interview map's legal states are `(mode_flag, map_installed, saved_cr)` and the transition set cannot be read off the code: `_state.interview_mode` has three writers (`enter`, `exit`, `refresh_state:1368`) while the map has two, so `refresh_state` is a documented transition that clears the flag and leaves the effect. It is currently masked by the crash. `_prepared_bufs`' permanence is correctly documented and tested in both directions (`:295`, `:308`) — that half is done well.

## 7. Plan revision recommendations

- **`## Revisions` — 2026-09-07, interview `<CR>` scope reversed twice.** Round 9 recorded "buffer-local shadows and unshadows" as the settled rule (in the atlas and in `lessons.md`); round 10 reversed it to "global, with `mapset` restore" on the grounds that `del` cannot distinguish ownership at any scope. Record the delta and the reason, per AGENTS.md §1 — the Core-concepts bullet was rewritten in place, which loses the fact that a decision changed.
- **`## Log` — rounds 9 and 10 have no entry.** The Log's last dated entry is the round-8 REWORK response. Two subsequent rounds of Important findings, three reversed decisions and a restored-then-deleted test block (the round-9 rewrite silently dropped four BR-38 tests, 29 → 25) are recorded only in commit messages.
- **`## Done when` — the master-switch bullet needs the carve-out it now has.** "verified by `:map` showing no parley mapping afterwards" is true only with nothing configured; the shipped switch deliberately honours `_explicit_shortcuts`. The atlas states this correctly; the Done-when does not.

```findings
dispose:
  - id: BR-47
    disposition: addressed
    note: |
      Verified by reversion — round 9's buffer-local shape reds both halves (spell's map destroyed; mode confined to one buffer); dropping the restore reds 3 more.
  - id: BR-48
    disposition: addressed
    note: |
      Verified by reversion — removing the two knobs from config.lua reds the new derived assertion. See the Minor on its substring predicate.
  - id: BR-49
    disposition: not-addressed
    note: |
      Headline fixed and pinned; two of the four shapes the finding enumerated still coerce silently — see N3.
  - id: BR-50
    disposition: addressed
    note: |
      All three parts verified — global plant reds 3, feature_gated has both guards, traceability guard reds on a real branch when a spec is unrouted.
  - id: BR-51
    disposition: addressed
    note: |
      Resolved by reverting the mechanism, so init.lua/spell.lua read true again — but the atlas and lessons.md were not swept back (N1).
  - id: BR-52
    disposition: not-addressed
    note: |
      The three blocks at keybinding_agreement_spec.lua:141-146, :163-168, :334-338 are untouched this round.
findings:
  - id: new
    severity: Important
    family: stale-comment-after-move
    title: |
      atlas and lessons.md still teach the interview-<CR> design round 10 reversed
    detail: |
      atlas/ui/keybindings.md:130 states "Interview's <CR> is buffer-local … del must never be aimed
      at a global map"; the shipped map is global (interview.lua:112) and round 10's own commit says
      del cannot distinguish ownership at ANY scope. workshop/lessons.md:1435 carries the same
      reversed claim as a RULE every agent reads at session start, so following it re-creates BR-47.
      4th in family. Rule — when a round reverses a prior round's decision, the artifacts that
      recorded it are part of the reversal's diff and are mechanically enumerable via
      `git show --stat` of the reversed commit: a84108a touched atlas/ui/keybindings.md,
      workshop/lessons.md, interview.lua and the issue; 5bc1a41 touched only the last two.
      Enumeration: the atlas paragraph, the lessons rule, and the missing ## Revisions / ## Log entry.
  - id: new
    severity: Important
    family: no-seam-for-ordering
    title: |
      the new interview tests drive setup_keymap/remove_keymap, never enter/exit — and enter/exit raises
    detail: |
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
  - id: new
    severity: Minor
    family: derive-before-validate
    title: |
      _explicit_shortcuts is computed from raw opts before setup() strips malformed values
    detail: |
      init.lua:546 walks the raw opts; the malformed-shortcut strip runs at :636. A knob whose value is
      later stripped stays marked explicit, so the master switch lets it through and it falls back to
      default_key. Measured — default_keymaps = false plus chat_shortcut_respond = { shortcut = 5 }
      binds <C-g><C-g>, a default key on a config that asked for none. Build the explicit set from the
      normalised config, or clear the entry when stripping.
  - id: new
    severity: Minor
    family: test-does-not-pin-the-fix
    title: |
      the BR-48 derived guard uses an unanchored substring, so 8 of 15 dotted knobs cannot fail it
    detail: |
      keybinding_agreement_spec.lua:526 asserts shipped_src:find(leaf, 1, true). Leaf "delete" occurs
      11 times in config.lua, "move" 7, "next_recency" 3 — so deleting note_finder_mappings.delete,
      chat_finder_mappings.move and six siblings leaves the test green. 5th in family. Rule — a derived
      assertion must be member-discriminating: verify it by deleting one member at a time for EVERY
      member, not for the two the finding happened to name. Anchor the match to an assignment.
  - id: new
    severity: Minor
    family: markdown-block-not-separated
    title: |
      README's "Every knob is named in config.lua" is swallowed into the preceding bullet
    detail: |
      README.md:277 follows a list item with no blank line, so GFM lazy continuation renders this
      section-level claim as part of the `u`/`<C-r>` bullet.
```
