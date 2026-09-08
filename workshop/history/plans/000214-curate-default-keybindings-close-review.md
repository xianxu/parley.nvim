# Boundary Review — parley.nvim#214 (whole-issue close)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | whole-issue close |
| milestone | — |
| window | 54a5c7a2ecaa3faf268d867f5222e73bd6f1dafb..59e9e2e7775df090cd35b9fd4c0ef8bf47cbfe7d |
| command | sdlc close --issue 214 |
| reviewer | claude |
| timestamp | 2026-09-08T12:46:34-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Eighteen rounds in, the code is in good shape: `make test` is green (200 spec files, MAKE_EXIT=0; luacheck 0 warnings / 0 errors across 356 files), every entity in the issue's Core-concepts tables exists at its stated path, and the two fixes this window claims are real — I verified BR-86 by reversion in a scratch worktree (restoring `selected == ""` turns `branch_child_spec.lua:1120` red with the measured line `a[🌿:   ](….md)b`), and BR-87/BR-70's doc sweep landed in both the atlas and the README. Twelve prior findings are now genuinely addressed. What keeps this off SHIP is the backlog: 26 prior findings remain open, three of them Important and one of them (BR-36) a measured user-visible defect on a shipped path — I reproduced it end-to-end (the debounced refresh appends ` ⚠️` to the topic line the user is typing on a foreign markdown buffer, 900ms after the keypress, and no test anywhere advances past that debounce). The one new finding is that `b20bc7c` added an atlas paragraph stating a key-ordering *policy* that the shipped config contradicts for 2 of the 9 members it enumerates — the eleventh instance of `docs-assert-unverified-behavior`, and the round that re-violated BR-23's own doc-sweep rule in the same commit.

## 1. Strengths

- **`branch_ref.topic_for_selection`'s guard now validates the derived value** (`init.lua:2451-2462`) and is pinned by a test that drives the real visual chord over whitespace. Verified by reversion, not by reading the commit message.
- **`resolve_keys` is pure and total again** (`keybinding_registry.lua:981`): the malformed-shortcut parse moved to the `setup()` boundary (`init.lua:617-716`), the resolver carries no logger dependency, and `keybindings_spec.lua:864` asserts that. This is the ARCH-PURE fix done at the right seam.
- **The superset guard covers keys AND modes in one loop** (`keybindings_spec.lua:418-448`), plus the "entries sharing a `config_key` declare identical defaults" rule — the general statement of why the `md_delete_file` twin was wrong, not a patch for the one site.
- **The parser change removed a mechanism rather than special-casing it** (`chat_parser.lua:598-620` deletes `line_before_local` outright), and the README ships an explicit upgrade note for the resulting `🔒:` semantic change (`README.md:270-280`) — a behavior change users can silently lose privacy to, documented before shipping.
- **`annotation.survivors` enumerates FORMS, not line positions** (`annotation.lua:70-84`), which is the axis three prior rounds missed, and it is pinned end-to-end by a real visual `<M-i>` followed by a real `delete_answer`.

## 2. Critical findings

None.

## 3. Important findings

**BR-36 (re-raised, measured this round) — `lua/parley/init.lua:2396`.** `insert_plain` calls `M.highlight_chat_branch_refs(buf)` *before* the `if not owns_file` early return, arming the 500ms debounce at `highlighter.lua:816`. No child exists on that path, so `render_chat_branch_line` sees `filereadable == 0` and rewrites the line. Measured on a foreign markdown buffer: immediately `🌿: <ts>.md: `, after typing `🌿: <ts>.md: my topic`, after 900ms `🌿: <ts>.md: my topic ⚠️` — in insert mode, on the line the user is composing. It does not accumulate across four refresh cycles. Fix sketch: move the refresh below the ownership branch, or have the debounce skip a ref whose target parley deliberately did not create.

**BR-23 (re-raised, re-violated in-window) — the changed-key doc sweep.** `b20bc7c` made `<M-g>` the primary for `open_file` and swept only `README.md` and `atlas/ui/keybindings.md`. Four atlas locations still present `<C-g>o` as the key: `atlas/context/file_references.md:15`, `atlas/chat/inline_branch_links.md:104,105,113`, `atlas/chat/format.md:16`. The rule BR-23 stated — sweep `grep -rn '<old-key>' README.md ARCH.md atlas/ docs/ lua/` in the same commit, plus a guard row in `tests/arch/single_source_sweeps_spec.lua` asserting no doc names a key that is not `resolve_keys(entry, config)[1]` — was never implemented; `single_source_sweeps_spec.lua` has no such row.

**BR-4 (re-raised, half-fixed) — `lua/parley/init.lua:2879-2886`.** The chat site now passes `chat_branch` directly (`:2681`), so `.i` is live there. The markdown site still hand-writes `i = function() vim.cmd("stopinsert"); md_branch.n() end`, which re-implements `.i` and additionally moves `stopinsert` *before* the pending-response refusal instead of after it. The consequence is a test-coverage gap, not just duplication: `branch_child_spec.lua:151` and `:233` iterate `n/i/v` over `_branch_inserters(b, true, false)`, so the `i` cell they exercise is the member markdown never installs. Fix sketch: pass `md_branch` directly, as the chat site does.

**NEW — `atlas/ui/keybindings.md:63-70` states an ordering policy the shipped config contradicts.** *This is the 11th finding in family `docs-assert-unverified-behavior`.* Earlier rounds fixed instances; do not fix this one. The rule that covers all of them, and the one BR-48 already introduced the machinery for: **a doc sentence that quantifies over registry entries is derived from `resolve_keys`, not typed.** Measured at HEAD by resolving every entry: `chat_drill_in` → `{<C-g>q, <M-q>}` (alt at 2) and `outline` → `{<C-g>t, <M-t>}` (alt at 2), so `<C-g>?` leads with the prefix spelling for both; and `skill_shortcut` is `<C-g>s` with no alt key at all. The new paragraph asserts "the **alt spelling leads** for transcript actions" and then names "quote, respond/define, accept, reject, branch, prune, outline, skill picker, and now follow-a-link" as that family — false for two members and vacuous for a third. The enumeration is mechanical: for each id the paragraph names, assert `resolve_keys(entry, config)[1]:match("^<M%-")`. `tests/integration/keybinding_agreement_spec.lua:526` is where the derived-claim precedent already lives.

## 4. Minor findings

- **BR-11** — `config_tools_spec.lua:436-447` still asserts `is_function` plus "a registry entry with this id exists"; replacing `init.lua:2716`'s `chat_toggle_tool_folds = M.cmd.ToggleToolFolds` with an inline closure leaves both green.
- **BR-18** — no test advances past the `stopinsert` → `schedule(edit + startinsert!)` sequence; `grep -rn '_branch_topic_timers\|TOPIC_REFRESH' tests/` returns nothing.
- **BR-25** — 10 CWD-relative `dofile("lua/parley/config.lua")` sites across 5 spec files; `b20bc7c` added an eleventh at `keybindings_spec.lua:888`.
- **BR-26** — `branch_ref_spec.lua` still has no case for a selection containing `](`; `splice_inline_link("see a](b", 5, 8, …)` emits `[🌿:a](b](f.md)`, whose parsed path is `b`, so the child on disk is unreachable.
- **BR-31** — `chat_finder.lua:784` still hand-builds `"[" .. branch_prefix .. topic .. "](" .. rel_path .. ")"`; the guard at `single_source_sweeps_spec.lua:424` still matches only the literal `branch_prefix .. " " ..` idiom.
- **BR-32** — half fixed: the success log now fires after the committed check (`init.lua:2427`), but `commit_reference` (`:2241`) still drops the `pcall` error, so a failed write reports no cause.
- **BR-35** — `branch_inserters(buf, abs_link, owns_file)` unchanged; `(true, true)` and `(false, false)` remain representable, meaningless and untested.
- **BR-37** — `c8cccd0` stands unamended; the staging rule already existed at `workshop/lessons.md:397` and was violated anyway, so the gap is enforcement, not the rule. Forward-looking: the tree currently carries five untracked `workshop/parley/` transcripts.
- **BR-52** — three near-identical `known`/diff blocks at `keybinding_agreement_spec.lua:141`, `:163`, `:334`.
- **BR-55** — measured reproducing: `setup({ default_keymaps = false, chat_shortcut_respond = { shortcut = 5 } })` yields `resolve_keys(chat_respond) = { "<C-g><C-g>" }` with `_explicit_shortcuts.chat_shortcut_respond = true`. `init.lua:548` walks raw `opts`; the strip at `:617` runs later and never clears the entry.
- **BR-56** — `keybinding_agreement_spec.lua:533` still uses `shipped_src:find(leaf, 1, true)` unanchored.
- **BR-57** — `README.md:289` "Every knob is named in…" still lazily continues the `u`/`<C-r>` bullet.
- **BR-71** — `init.lua:2276` still parses the whole buffer before the gather at `:2288`, and the comment at `:2283` ("ask it first") describes an ordering the code does not have.
- **BR-72** — `apply_text_edits` (`:2337`), `handle_line` (`:2339`) and `nvim_buf_set_lines` (`:2350`) still follow the pcall'd `create_child_if_owned` unguarded.
- **BR-73** — `branch_submit_spec.lua:126` still passes `{}` for a boolean; `:131` still names a content check `plan_submission` never makes.
- **BR-74** — the dangling fragment survives at issue `:826-827`; additionally the M2 close Log bullet now sits *inside* `## Revisions`, between entries 10 and 11.
- **BR-77** — both sites unchanged (`helper.lua:116`, `drill_in.lua:340-346`), plus `buffer_edit.lua:96`. `tests/arch/superseded_comment_spec.lua`'s annotation lint cannot see either: it requires `#params > 0`, and `uuid`'s orphaned block is `@return`-only.
- **BR-81** — `branch_submit.lua:26-31` and `branch_child_spec.lua:408-412` still assert the `line_before_local` latch that `b9fc6c8` removed inside this window, in the present tense.
- **BR-82** — `annotation.lua` / `annotation_lines_spec.lua` are routed under `ui/keybindings`, while `atlas/chat/parsing.md:85` cites the spec by name; `make test-changed` on that doc still does not run it.
- **BR-83** — `:322` still cites "the measured reason the ref follows `📝:`" and Open risks still names case 2b's "last exchange". (The `milestone-close` tick at `:330` is now retroactively true — `281ce19` carries the verdict trailer and the Log has the M3 entry.)
- **BR-84** — `buffer_edit.lua:108-109` unchanged; every test still calls `delete_answer` directly.
- **BR-88** — `annotation.lua:14-15` still claims four consumers; `grep -rn 'require("parley.annotation")'` returns exactly `chat_parser.lua:313` and `buffer_edit.lua:119`.
- **BR-89** — both constant-true ternaries survive at `init.lua:2352-2353` and `:2400-2402`.
- `atlas/chat/inline_branch_links.md:7` names the signature `branch_inserters(buf, abs_link)`; the code is `(buf, abs_link, owns_file)`, and `owns_file` is the parameter the whole guarantee table on the next lines turns on.

## 5. Test coverage notes

Suite green: 200 spec files pass, luacheck clean across 356 files. Coverage added this window is real — `branch_child_spec.lua` drives the dispatch table over modes × buffer types, `keybinding_agreement_spec.lua` closes the leak/ghost check against a real prepped buffer, and BR-10/BR-17 (named as unpinned by BR-20) both gained tests. Three gaps remain that would catch the kind of bug this diff ships: (a) no test crosses a `vim.schedule` or a debounce boundary anywhere in the branch paths, which is exactly why BR-36 survived six rounds; (b) the markdown `i` cell tested is not the markdown `i` cell registered; (c) `plan_submission`'s two decline tests pass through branches unrelated to their names, so the content check one of them advertises could be added and broken without turning it red.

## 6. Architectural notes

- **ARCH-DRY — flag.** Four live duplications: the markdown `.i` wrapper (BR-4), `chat_finder.lua:784` (BR-31), the three `known`-set blocks (BR-52), and — outside the milestone's declared scope but now touched by it — three hand-rolled chat-file-creation blocks at `init.lua:4245`, `:4388`, `:4550` that re-implement `create_child_chat`'s template + writefile + back-link sequence. The branch-ref *line* formatter, by contrast, has one owner and a guard: that half is clean.
- **ARCH-PURE — pass, with one consequence.** `resolve_keys`, `branch_ref`, `branch_submit` and `annotation` are pure and unit-tested without IO. The one violation of the spirit is `render_chat_branch_line`, which performs `filereadable` + a file read inside a debounce that then rewrites buffer text — BR-36 is that seam failing.
- **ARCH-PURPOSE — pass on the code, flag on the docs.** The single-source claim ("every key derives from `resolve_keys`") is *enforced* by `single_source_sweeps_spec.lua:481`, not merely documented. The remaining hand-maintained restatement of the model is the documentation layer: no consumer derives a key spelling from `resolve_keys`, which is BR-23's rule and the new finding's rule, and it is why the same class has now produced five findings.
- **ARCH-MOCK — pass.** No new external binary or service dependency; the filesystem is exercised through real temp roots in the integration specs, and the harness relocates `HOME`/`XDG_*`/`TMPDIR` out of the tree.
- **ARCH-CONSTRAINTS — flag.** `<M-i>` is an interactive keypress path that runs two full-buffer passes (BR-71, ~13ms on a 2500-line chat) with no declared envelope, and the 500ms debounce rewrites buffer text with no stated bound on what it may rewrite.
- **ARCH-SECURE — pass.** The gsub-replacement class is swept to function replacements and enforced by an arch guard with explicit `-- gsub-safe:` annotations rather than name-inference; `flatten_lines` closes the `writefile` NUL hole; the whitespace-selection guard now validates the derived topic. BR-26 is the residual: a selection containing `](` produces a link whose parsed path is not the file that was created.
- **ARCH-ORDER — flag, and this is the highest-leverage one for the next milestone.** Three open findings are the same shape: BR-18/BR-36 (no seam to inject or observe the schedule/debounce interleaving, so every green run is a sample of size one), BR-35 (two independent booleans declaring four states where two are legal), BR-72 (the point of no return moved and the effects after it are now the unguarded ones). The debounce seam is worth building once — `_parley._branch_topic_timers[buf]` is already module-visible, so a test helper that drains it deterministically would pin all of BR-18, BR-36 and any future timer-armed branch path.

## 7. Plan revision recommendations

- **`workshop/plans/000214-branch-submit-m3-plan.md`** — append a `## Revisions` entry recording that Task 8 Step 1's "including the measured reason the ref follows `📝:`" is superseded (placement is the cursor), and that Open risks item 2 ("Case 2b's 'last exchange'") describes a case the narrowing removed. Do not edit the rows in place.
- **`workshop/issues/000214-curate-default-keybindings.md`** — two structural repairs the artifact needs before it archives: the two-line fragment stranded at `:826-827` after the "single-line annotations" revision body, and the M2 close Log bullet that now sits inside `## Revisions` between entries 10 and 11. Also worth one line: revision 16 states "the real fix is a parser change … which is not this milestone's to make", and revision 15 records that the milestone made it — the later entry should say it supersedes that clause.
- **`atlas/ui/keybindings.md`** — the alt-family paragraph added by `b20bc7c` needs either the two contradicting members corrected in `config.lua` (`chat_drill_in`, `outline`) or the paragraph narrowed to the three entries where the alt spelling actually leads. Whichever, per the family rule the claim should be backed by a derived assertion rather than restated.

---

## Re-review — 2026-09-08T13:00:36-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 214 — audit and curate the default keybinding surface |
| repo | parley.nvim |
| issue file | workshop/issues/000214-curate-default-keybindings.md |
| boundary | whole-issue close |
| milestone | — |
| window | 54a5c7a2ecaa3faf268d867f5222e73bd6f1dafb..172384d080aec02916c30529f0c2680cccd2f378 |
| command | sdlc close --issue 214 |
| reviewer | claude |
| timestamp | 2026-09-08T13:00:36-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Twelve of the 38 carried findings genuinely closed inside this window — BR-86's whitespace-topic guard and BR-4's dispatch-table collapse both land with tests that go red on revert, BR-49 restored `resolve_keys` to a pure, logger-free resolver, BR-53/BR-54 finished the interview `<CR>` reversal in the artifacts *and* through the real `enter()`/`exit()` transition, and BR-2/BR-24/BR-29/BR-30/BR-34/BR-70/BR-87 all check out against the code rather than the commit message. The suite is green (`make test`: 200 spec files, exit 0) and `luacheck` reports 0 warnings / 0 errors across 356 files. What keeps this off SHIP is not a correctness bug — there is no Critical — it is that three of the carried Importants are *rules* the rounds keep restating and not mechanising, and one of them recurred inside this window's own last commit: `b20bc7c` moved `open_file` to `<M-g>` and left four atlas sites naming `<C-g>o` as the key, which is exactly the enumeration BR-23 asked for and the guard row BR-23 asked for still does not exist. Plus one new gap: the Spec's `<M-*>` portability bullet is neither delivered nor recorded as deferred, in a milestone that added three more alt-chord defaults.

## 1. Strengths

- **BR-86's fix guards the value that is used, and is pinned end-to-end.** `init.lua:2451-2460` rejects the *derived* topic and `branch_child_spec.lua:1096-1127` drives the real visual chord over the three spaces in `a   b`, asserting both that the line is unspliced and that no child file appeared. Reverting to `selected == ""` turns both assertions red — that is the class fix, not the site fix.
- **`resolve_keys` is pure again, and the assertion says so.** Moving malformed-shortcut normalisation to `init.lua:638-717` and asserting at `keybindings_spec.lua:864+` that the registry carries no logger dependency closes BR-49 at the boundary the finding named, rather than validating harder at every read.
- **The superset guard covers keys *and* modes in one loop** (`keybindings_spec.lua:418-449`), plus the "entries sharing a config_key declare identical defaults" rule at `:453-473`. That is the general statement of the `md_delete_file` C2 defect, and it also retires BR-24 — the registry/config chord duplication is now compared rather than trusted.
- **`branch_ref.lua` went from zero tests to a spec that covers the inverted span, the nil topic, and the whitespace-only selection** (`branch_ref_spec.lua`), and the module plus its spec are routed in `atlas/traceability.yaml:691-708`.
- **The interview `<CR>` tests now drive the transition a user triggers** (`keybinding_agreement_spec.lua:445-513`, `:597+`) and the libuv handle moved out of the deepcopied `_state` to a module-local at `interview.lua:193` — the reversal that took three rounds is now pinned through the real lifecycle.

## 2. Critical findings

None.

## 3. Important findings

- **BR-23 (re-raised, not-addressed) — `atlas/chat/format.md:16`, `atlas/context/file_references.md:15`, `atlas/chat/inline_branch_links.md:104,105,113`.** Two named instances were fixed; the rule was not. `b20bc7c` shipped `<M-g>` as `open_file`'s primary with `<C-g>o` demoted to legacy, updated `README.md:189` and `atlas/ui/keybindings.md`, and left four atlas sites naming `<C-g>o` as the key. The guard row BR-23 specified — "no doc names a key that is not `resolve_keys(entry, config)[1]`" — is still absent from `tests/arch/single_source_sweeps_spec.lua`, whose only key-related guard is the picker-literal count at `:373`.
- **BR-36 (re-raised, not-addressed) — `init.lua:2396` precedes the `if not owns_file` return at `:2407`.** `highlight_chat_branch_refs` arms the 500 ms debounce (`highlighter.lua:811-841`) on the foreign-markdown path, where no child is created, so `render_chat_branch_line` sees `filereadable == 0` and rewrites the line with `⚠️` appended after whatever the user has typed, in insert mode. `branch_child_spec.lua:181-204` asserts only the synchronous state and therefore stays green.
- **BR-20 (re-raised, not-addressed).** Measured this round: both fixes that landed (BR-4, BR-86) *are* pinned by tests that go red on revert — that half is good. The rule is still not mechanised: BR-80's fix (round 17) has no pinning test at all, and the new `branch_child_spec.lua:1141-1148` ("the constructor's `i` is reachable, not dead") asserts something that was true before the fix, since `.i` was never missing from the constructor — the deadness was at the call site, which only the sibling grep test at `:1133-1139` actually pins.
- **NEW — the Spec's `<M-*>` portability bullet is neither delivered nor deferred.** `workshop/issues/000214-curate-default-keybindings.md:97` asks to "review the `<M-*>` family for terminal portability" and names `<M-CR>`'s two-entry split as the motivating case. No such review exists in the issue, the atlas or the Log, and the Deferred note covers only the ariadne split. Measured: `config.lua` ships 10 alt-chord defaults; the five this milestone touched (`<M-i>`, `<M-p>`, `<M-g>`, `<M-t>`, `<M-q>`) all carry a `<C-g>` alias, and the five it did not (`chat_shortcut_define` `<M-CR>:358`, `review_shortcut_next` `<M-CR>:463`, `<M-a>:454`, `<M-r>:455`, `<M-o>:462`) carry none — the portability mitigation was applied to the keys the milestone happened to edit, not to the family the Spec named. The `<M-CR>` split (`keybinding_registry.lua:505-517` and `:757-766`) is unchanged. Fix is cheap: one paragraph in `atlas/ui/keybindings.md` enumerating the alt family and which members have a non-alt spelling, **or** one line in the Deferred note.

## 4. Minor findings

- BR-11 — `config_tools_spec.lua:438-446` still asserts `is_function` + registry presence; reverting `init.lua:2716` to an inline closure leaves it green.
- BR-18 — the seam at `init.lua:2506` exists; no test drives the `stopinsert` → `schedule(startinsert!)` interleaving.
- BR-25 — `dofile("lua/parley/config.lua")` is CWD-relative at `keybindings_spec.lua:373,397` and `keybinding_agreement_spec.lua:526`.
- BR-26 — `branch_ref_spec.lua` still has no case for a selection containing `](`.
- BR-31 — `chat_finder.lua:784` hand-builds the *inline* link while `:772` correctly calls `format_ref_line`; the guard at `single_source_sweeps_spec.lua:424` still matches only `branch_prefix .. " " ..`.
- BR-32 — half fixed: the success log now follows the commit check (`init.lua:2427-2430`); `local ok = pcall(...)` at `:2241` still drops the cause.
- BR-35 — `branch_inserters(buf, abs_link, owns_file)` at `init.lua:2206`; two booleans, two illegal states, unchanged.
- BR-37 — no strengthened staging rule; `lessons.md:397` predates the finding and `c8cccd0` violated it anyway.
- BR-52 — `keybinding_agreement_spec.lua:141`, `:163`, `:334` still rebuild `known` three times.
- BR-55 — `_explicit_shortcuts` built from raw `opts` at `init.lua:548`; the strip runs at `:646`.
- BR-56 — `keybinding_agreement_spec.lua:534` still `find(leaf, 1, true)`, unanchored.
- BR-57 — `README.md:289` follows the bullet at `:285-288` with no blank line; GFM lazy continuation swallows it.
- BR-71 — `init.lua:2277` parses the whole buffer before the gather at `:2287`; the comment at `:2280-2285` describes the opposite order.
- BR-72 — enumeration is wider than named: `insert_inline` (`:2465` then `:2466`) and `insert_plain` (`:2395` then `:2424`) both mutate the parent *before* creating the child, unguarded — BR-63's ordering fix reached only `insert_planned`.
- BR-73 — `branch_submit_spec.lua:125` still passes `{}` for a boolean; `:131` still names a content check `plan_submission` never makes.
- BR-74 — the dangling fragment is at issue `:828-829`; additionally the M2-close **Log** bullet now sits inside `## Revisions` at `:750`.
- BR-77 — `helper.lua:116`, `drill_in.lua:340`, `buffer_edit.lua:96` all still splice into a neighbour's block.
- BR-81 — `branch_submit.lua:26-31` and `branch_child_spec.lua:408-412` still assert the `line_before_local` latch `b9fc6c8` removed.
- BR-82 — `traceability.yaml:97-112` (`chat/parsing`) lists neither `annotation.lua` nor `annotation_lines_spec.lua`; the module appears in no `atlas/*.md`.
- BR-83 — m3-plan `:322` and Open risks `:339` still describe superseded decisions; the `:330` milestone-close tick is now legitimate (`281ce19` carries the verdict trailer).
- BR-84 — `buffer_edit.lua:108-109` still claims survivors do not drift to the end.
- BR-88 — `annotation.lua:14-15` claims four consumers; `grep` returns `chat_parser.lua:313` and `buffer_edit.lua:119`.
- BR-89 — `init.lua:2352-2353` and `:2393-2395` are still constant-true ternaries.
- (context, not a finding) `atlas/chat/inline_branch_links.md:7` writes the signature as `branch_inserters(buf, abs_link)`; the shipped one takes three arguments.

## 5. Test coverage notes

Green and lint-clean: `make test` → 200 spec files, exit 0; `make lint` → 0 warnings / 0 errors in 356 files. Coverage on the branch paths is genuinely good — `branch_child_spec.lua` iterates modes × buffer types (`:137-155`, `:218-236`) rather than naming a path, which is what closed BR-28's third occurrence, and the resubmit-survivor case is driven end-to-end through a real visual `<M-i>` followed by a real `delete_answer` (`:1033-1088`). The gaps that remain are all oracle-shaped rather than absent: three specs assert something that was already true (BR-11, BR-73, the new BR-4 reachability test), one derived assertion is member-blind (BR-56), and the two paths that carry a timer or a schedule (BR-18, BR-36) have no test that advances past them, so a green run there is a sample of size one.

## 6. Architectural notes

- **ARCH-DRY — flag.** BR-31 (`chat_finder.lua:784`) and BR-52. The consolidation itself is real, but the guard that defends it is keyed on one spelling of the concatenation instead of the emitted shape, so it cannot see the inline sibling. BR-24 now passes: the superset guard compares config against the registry rather than leaving the duplication unasserted.
- **ARCH-PURE — mostly pass.** `resolve_keys` is logger-free and total (BR-49 closed); `branch_ref`, `branch_submit` and `annotation` are pure with direct unit tests and no mocks. One flag: BR-36 arms an IO-touching debounce from a path whose whole contract is "no file is created".
- **ARCH-PURPOSE — flag.** Shadow-sweep of the single-source claim: every key parley binds now derives from `resolve_keys`, and the arch guard at `single_source_sweeps_spec.lua:474-509` enforces zero raw `.shortcut` reads — that consumer set is genuinely closed. The *documentation* consumer is not: four atlas sites still restate a key by hand (BR-23), and the Spec's `<M-*>` bullet is the "easy subset" case — the portability mitigation shipped for the five keys the milestone edited and for none of the five it did not.
- **ARCH-MOCK — pass / N/A.** No new external binary or service dependency; tests run the real Neovim runtime against per-run scratch trees under `$TMPDIR` (`TOOLING.md`), so production and test flow share the boundary.
- **ARCH-CONSTRAINTS — flag.** BR-71: `<M-i>` is a keystroke path now doing two full-buffer passes (`M.parse_chat` at `init.lua:2277`, then `gather_edit_plan` at `:2287`) with no declared envelope, and on the common no-marker path the first result is discarded.
- **ARCH-SECURE — pass.** The gsub-replacement class is swept and enforced by an annotation-based guard (`single_source_sweeps_spec.lua:440-468`) rather than inferred from variable names; `chat_slug.slugify` strips path separators and non-ASCII before a topic becomes a filename; BR-86 closed the derived-empty-topic hole. No credential surface in this diff.
- **ARCH-ORDER — flag.** Three open instances: BR-36 (a timer armed on a path with no seam to observe it), BR-18 (no interleaving test for `stopinsert`/`schedule`), BR-72 (the effect sequence after the point of no return is guarded at one of three sites). BR-35 is the state half: `branch_inserters(buf, abs_link, owns_file)` declares four states and means two — collapsing to `kind = "chat" | "foreign"` is the tagged enum that makes the illegal pair unrepresentable.

## 7. Plan revision recommendations

- `workshop/plans/000214-branch-submit-m3-plan.md` — append a `## Revisions` entry (BR-83): Task 8 Step 1 at `:322` still ticks "including the measured reason the ref follows `📝:`", and Open risks at `:339` still names case 2b's "last exchange"; both were superseded by the cursor-placement reversal. The `:330` milestone-close row is now correct and needs no change.
- `workshop/issues/000214-curate-default-keybindings.md` — two edits (BR-74, and the new finding): remove the stranded fragment at `:828-829` and move the M2-close Log bullet at `:750` out of `## Revisions` back under `## Log`; and either add an 18th revision recording the `<M-*>` family review (which the evidence in §3 above nearly is) or extend the "Deferred to after #212" note to say the `<M-*>` portability bullet and the `<M-CR>` two-entry split are deferred and to what.

```findings
dispose:
  - id: BR-2
    disposition: addressed
    note: |
      branch_ref_spec.lua covers splice (incl. inverted span), format_ref_line nil topic, topic_for_selection and ref_block; traceability.yaml:694,701 lists module + spec.
  - id: BR-4
    disposition: addressed
    note: |
      Both sites pass md_branch/chat_branch whole (init.lua:2683,2883); the grep test at branch_child_spec.lua:1133 goes red on revert.
  - id: BR-11
    disposition: not-addressed
    note: |
      config_tools_spec.lua:438-446 still asserts is_function plus registry presence; reverting init.lua:2716 to an inline closure leaves it green.
  - id: BR-18
    disposition: not-addressed
    note: |
      The seam at init.lua:2506 is used by 21 call sites but none observes the stopinsert/schedule(startinsert!) interleaving.
  - id: BR-20
    disposition: not-addressed
    note: |
      This round's two fixes ARE pinned; BR-80's still has none, and branch_child_spec.lua:1141 asserts what was already true before the BR-4 fix.
  - id: BR-23
    disposition: not-addressed
    note: |
      Guard row never written; b20bc7c shipped <M-g> and left 4 atlas sites naming <C-g>o as primary (format.md:16, file_references.md:15, inline_branch_links.md:104,105,113).
  - id: BR-24
    disposition: addressed
    note: |
      keybindings_spec.lua:418-449 now asserts every registry default_key appears in the shipped config value (keys AND modes); order pinned at :375-380.
  - id: BR-25
    disposition: not-addressed
    note: |
      Still CWD-relative at keybindings_spec.lua:373,397 and keybinding_agreement_spec.lua:526.
  - id: BR-26
    disposition: not-addressed
    note: |
      branch_ref_spec.lua has no case for a selection containing "](".
  - id: BR-29
    disposition: addressed
    note: |
      inline_branch_links.md:15-19 now states no child / no save / cursor+insert for foreign markdown and "saves the parent yes" for chat.
  - id: BR-30
    disposition: addressed
    note: |
      "## Revisions" exists at issue :667 with entries 4/5/6 covering the three superseded M1 decisions.
  - id: BR-31
    disposition: not-addressed
    note: |
      chat_finder.lua:784 still hand-builds the inline link; the guard at single_source_sweeps_spec.lua:424 still matches only `branch_prefix .. " " ..`.
  - id: BR-32
    disposition: not-addressed
    note: |
      Log ordering fixed (init.lua:2427-2430); the write error is still discarded at init.lua:2241.
  - id: BR-34
    disposition: addressed
    note: |
      All {{topic}}/initial_question substitutions use function replacements; arch guard at single_source_sweeps_spec.lua:440-468 with an explicit gsub-safe annotation.
  - id: BR-35
    disposition: not-addressed
    note: |
      init.lua:2206 still takes (buf, abs_link, owns_file); two of four representable states remain illegal and untested.
  - id: BR-36
    disposition: not-addressed
    note: |
      init.lua:2396 still arms the debounce before the `if not owns_file` return at :2407; highlighter.lua:833 rewrites the line with the warning 500ms later.
  - id: BR-37
    disposition: not-addressed
    note: |
      No strengthened staging rule landed; lessons.md:397 predates the finding (added 2026-07-01 for #157) and c8cccd0 violated it anyway.
  - id: BR-49
    disposition: addressed
    note: |
      Validation moved to init.lua:638-717; registry has no logger reference and keybindings_spec.lua:864+ asserts that.
  - id: BR-52
    disposition: not-addressed
    note: |
      keybinding_agreement_spec.lua:141, :163 and :334 still rebuild the known set inline.
  - id: BR-53
    disposition: addressed
    note: |
      atlas/ui/keybindings.md:138 states the map is global with restoring teardown; lessons.md rule 5 rewritten to "teardown must restore what it shadowed - scope is not the fix".
  - id: BR-54
    disposition: addressed
    note: |
      keybinding_agreement_spec.lua:445-513 and :597+ drive enter()/exit(); the libuv handle moved to a module-local at interview.lua:193.
  - id: BR-55
    disposition: not-addressed
    note: |
      init.lua:548 builds _explicit_shortcuts from raw opts; the malformed strip runs at :646 on M.config, so a stripped knob stays marked explicit.
  - id: BR-56
    disposition: not-addressed
    note: |
      keybinding_agreement_spec.lua:534 still uses an unanchored `find(leaf, 1, true)`.
  - id: BR-57
    disposition: not-addressed
    note: |
      README.md:289 still follows the bullet at :285-288 with no blank line.
  - id: BR-70
    disposition: addressed
    note: |
      atlas/chat/drill_in.md:130-140 and :164-165 both name drill_in.chat_gather_opts as the owner with chat_respond as a consumer.
  - id: BR-71
    disposition: not-addressed
    note: |
      init.lua:2277 still parses the whole buffer before the gather at :2287; the comment at :2280-2285 claims the opposite order.
  - id: BR-72
    disposition: not-addressed
    note: |
      Enumeration wider than named - insert_inline (init.lua:2465 then :2466) and insert_plain (:2395 then :2424) both mutate the parent before creating the child, unguarded; BR-63's ordering fix reached only insert_planned.
  - id: BR-73
    disposition: not-addressed
    note: |
      branch_submit_spec.lua:125 still passes `{}` for a boolean; :131 still names a content check plan_submission never makes.
  - id: BR-74
    disposition: not-addressed
    note: |
      Fragment still at issue :828-829; additionally the M2-close Log bullet now sits inside "## Revisions" at :750, the same rule in the other direction.
  - id: BR-77
    disposition: not-addressed
    note: |
      helper.lua:116, drill_in.lua:340 and buffer_edit.lua:96 all still splice into a neighbour's block.
  - id: BR-81
    disposition: not-addressed
    note: |
      branch_submit.lua:26-31 and branch_child_spec.lua:408-412 still assert the latch b9fc6c8 removed; atlas/chat/parsing.md:68 correctly says "used to latch".
  - id: BR-82
    disposition: not-addressed
    note: |
      traceability.yaml:97-112 (chat/parsing) lists neither annotation.lua nor annotation_lines_spec.lua; the module appears in no atlas/*.md.
  - id: BR-83
    disposition: not-addressed
    note: |
      m3-plan :322 and Open risks :339 still describe superseded decisions; the :330 milestone-close tick is now legitimate since 281ce19 carries the verdict trailer.
  - id: BR-84
    disposition: not-addressed
    note: |
      buffer_edit.lua:108-109 unchanged; every test still calls delete_answer directly.
  - id: BR-86
    disposition: addressed
    note: |
      init.lua:2451-2460 guards the derived topic; branch_child_spec.lua:1096-1127 drives the real visual chord over whitespace and both assertions go red on revert.
  - id: BR-87
    disposition: addressed
    note: |
      README.md:185-188 and atlas/chat/inline_branch_links.md:61-75 both describe the survivor transformation, including the inline-to-standalone reformat.
  - id: BR-88
    disposition: not-addressed
    note: |
      annotation.lua:14-15 still claims four consumers; grep returns chat_parser.lua:313 and buffer_edit.lua:119.
  - id: BR-89
    disposition: not-addressed
    note: |
      init.lua:2352-2353 and :2393-2395 still carry the constant-true ternaries.
findings:
  - id: new
    severity: Important
    family: spec-item-neither-delivered-nor-deferred
    title: |
      the Spec's <M-*> terminal-portability review is neither delivered nor recorded as deferred, in a milestone that added three more alt-chord defaults
    detail: |
      Issue :97 asks to "review the <M-*> family for terminal portability" and names
      <M-CR>'s two-entry split as the motivating case. No such review exists in the
      issue, the atlas or the Log, and the "Deferred to after #212" note covers only
      the ariadne split, so the bullet simply vanished. Measured against config.lua:
      ten alt-chord defaults ship. The five this milestone touched (<M-i>:408,
      <M-p>:400, <M-g>:384, <M-t>:389, <M-q>:453) each carry a <C-g> alias; the five
      it did not (chat_shortcut_define <M-CR>:358, review_shortcut_next <M-CR>:463,
      <M-a>:454, <M-r>:455, <M-o>:462) carry none, so on a terminal that cannot
      deliver alt chords those five actions have no key at all. The <M-CR> split the
      Spec named is unchanged at keybinding_registry.lua:505-517 and :757-766. This
      is ARCH-PURPOSE's instance-not-class shape: the portability mitigation was
      applied to the keys the milestone happened to edit rather than to the family
      the Spec named. Cheap fix - one paragraph in atlas/ui/keybindings.md
      enumerating the alt family and which members have a non-alt spelling, or one
      line extending the Deferred note.
```
