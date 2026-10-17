# Boundary Review — parley.nvim#377 (whole-issue close)

| field | value |
|-------|-------|
| issue | 377 — Remap keys: Alt+i pastes an image (matching pair draft), Alt+b creates a sub-chat |
| repo | parley.nvim |
| issue file | workshop/issues/000377-remap-alt-i-image-alt-b-branch.md |
| boundary | whole-issue close |
| milestone | — |
| window | 81fecd406998589d02bd6724efdac42939399ea9..5e972a463e22da22aa39ee329ee611489ee0376a |
| command | sdlc close --issue 377 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T12:55:51-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Found two user-facing docs that still say Alt+v. Now checking the starter config source and the test at keybinding_agreement_spec:280.

Running the targeted specs now (timeout isn't installed, so I'm running them without it).

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The remap itself is correct. In `lua/parley/config.lua:426,432` and `lua/parley/keybinding_registry.lua:571,601`, paste_image now defaults to `{ "<M-i>" }` and branch_ref to `{ "<M-b>", "<C-g>i" }`. `<M-v>` is now unbound, and a test pins that in both n and i mode. README, atlas, help text and the specs that pin these keys are updated, and the targeted specs I ran pass. One thing blocks SHIP: the sweep stopped at README and atlas. The shipped tutorials and the starter-config README still teach the old keys. `packaging/tutorials/basics.md` tells users that `option+i` on a selection creates a linked chat, but that key now pastes an image in n/i and does nothing in v. `advanced.md` and the starter README say Alt/Option+v, which is now unbound. This is cheap to fix, but it misleads users directly.

1. **Strengths**
   - Registry and config defaults move together. `config.lua` stays the shipped source, as the registry comment at `keybinding_registry.lua:568-570` requires. `tests/unit/keybindings_spec.lua:372` pins the shipped file directly.
   - The new negative assertion `tests/integration/paste_image_spec.lua:109-110` checks both modes of the "`<M-v>` not bound" clause, which is what the Done-when asks for.
   - `keybinding_agreement_spec.lua:661` checks both `<M-i>` and `<M-b>` against the published reference and against live bindings.
   - The help-lead rule (alt key first, `<C-g>i` shown as an alias) is kept, and `keybindings_spec.lua:353,385` assert it.
2. **Critical**: none.
3. **Important**
   - Shipped tutorials and the starter README still name the old keys (see the findings block for every instance). Fix sketch: `option+i` → `option+b` for branching, `option+v` / `Alt+v` → `option+i` / `Alt+i` for image paste.
4. **Minor**
   - Some history comments were rewritten to the new key, so they now misstate the past. For example, `atlas/chat/drill_in.md:166` says "which is how `<M-b>` came to disagree", but that #214 bug was on `<M-i>`, and `<M-b>` did not exist yet. Other instances: `branch_submit.lua:22`, `drill_in.lua:349`, `buffer_edit.lua:231`, `atlas/chat/inline_branch_links.md:54`, `tests/unit/branch_submit_spec.lua:508`, `tests/integration/branch_child_spec.lua:5`. The Log says history notes were left alone, but these are history notes too.
   - `tests/integration/keybinding_agreement_spec.lua:280` asserts that `<M-i>` is absent so "the default set came back too" is caught. It still passes, but `<M-i>` now means paste_image instead of branch, so the check means something different. Consider adding `<M-b>` there.
   - A user who explicitly set `chat_shortcut_branch_ref` to the old `{ "<M-i>", ... }` now collides with the new paste_image default on `<M-i>`. The Spec accepts this ("keeps their own keys"); a release note would help.
5. **Test coverage**
   - The specs I ran pass: the `ui/keybindings` mapped set and `chat/attachments`.
   - One failure, `file_history_spec.lua:255` ("src Alt+o landing"), also fails at base 81fecd40, so this diff didn't cause it.
   - Nothing checks tutorial or packaging prose against the registry. That is why the stale keys got through.
6. **Architecture**
   - ARCH-DRY: pass. The keys live in config.lua plus the registry fallback, which is the existing arrangement, and nothing is duplicated.
   - ARCH-PURE: pass. Only data and comments changed.
   - ARCH-PURPOSE: flag. The point of the issue is one image key that users learn. The Done-when names Help, README and atlas, but the tutorials are the main place users learn keys, and they still restate the old model by hand.
7. **Plan revisions**: add a `## Revisions` entry saying the docs sweep also covers `packaging/tutorials/*`, `packaging/starter-config/README.md` and `workshop/parley/*`.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: key-remap-doc-sweep
    title: |
      Shipped tutorials and starter README still teach the old keys (option+i branches, option+v/Alt+v pastes)
    detail: |
      All instances in the tree: packaging/tutorials/basics.md:76 (option+i on a selection creates a linked chat; should be option+b, since M-i is now n/i paste and unbound in v); packaging/tutorials/advanced.md:126 (option+v; should be option+i); packaging/starter-config/README.md:67 (Alt+v; should be Alt+i); workshop/parley/welcome.md:15 (Alt+v); workshop/parley/basics.md:61,72 (Option+i for branch); workshop/parley/advanced.md:63 (Option+i for branch), :139 (Option+v). ARCH-PURPOSE: no test ties tutorial key prose to the registry, so these drifted silently. Consider a cheap spec that greps the packaging/tutorials files for the paste_image/branch_ref keys.
  - id: new
    severity: Minor
    kind: defect
    family: history-notes-rewritten
    title: |
      History comments rewritten from M-i to M-b now misstate the past
    detail: |
      atlas/chat/drill_in.md:166 says the 214 bug was on M-b, a key that did not exist then. Same rewrite at lua/parley/branch_submit.lua:22, lua/parley/drill_in.lua:349, lua/parley/buffer_edit.lua:231, atlas/chat/inline_branch_links.md:54, tests/unit/branch_submit_spec.lua:508, tests/integration/branch_child_spec.lua:5. Either say "the branch key" or keep M-i with a "(now M-b, 377)" note.
  - id: new
    severity: Minor
    kind: defect
    family: stale-test-intent
    title: |
      keybinding_agreement_spec.lua:280 still checks M-i, which now means paste_image instead of branch
    detail: |
      It still passes, but the key it checks now belongs to paste_image. Add or replace it with M-b so the branch default is covered under default_keymaps=false.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"ef08c0a1-ed71-42f4-85e8-f036a2e1045e","repository":"github.com/xianxu/parley.nvim","issue_id":"000377","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/9cb114540eb23ee8","reviewed_head":"5e972a463e22da22aa39ee329ee611489ee0376a","slot":"parley.nvim:4","requested_at":"2026-10-17T19:51:16.532636Z"},"phase":"finished","pid":49552,"started_at":"2026-10-17T19:51:16.627681Z","finished_at":"2026-10-17T19:55:47.31533Z","session_id":"cdd94c89-d492-4788-88b5-cdfcc98ea669","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T13:50:08-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 377 — Remap keys: Alt+i pastes an image (matching pair draft), Alt+b creates a sub-chat |
| repo | parley.nvim |
| issue file | workshop/issues/000377-remap-alt-i-image-alt-b-branch.md |
| boundary | whole-issue close |
| milestone | — |
| window | 81fecd406998589d02bd6724efdac42939399ea9..131c684c6ca6fde3af69e7fb119e31c9c523510f |
| command | sdlc close --issue 377 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T13:50:08-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I've checked the diff and searched the whole tree for old key spellings. Now I'm running the agreement spec that the fix added.

Every keybindings spec passed except one: `file_history_spec` "src Alt+o", which this diff doesn't touch. Now I'm checking the code side of the diff (config, registry, paste_image).

I've found one more stale history comment (`init.lua:2472`). Next I'm checking that the new tutorial spec actually fails when a tutorial teaches the old key.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

All three earlier findings are fixed. The new default keys are what the issue asked for: image paste is on `<M-i>`, sub-chat creation is on `<M-b>` plus `<C-g>i`, and `<M-v>` is left unbound. README and atlas now name the new keys. The new spec ties the shipped tutorials to the registry, and I confirmed it really catches drift. I changed `packaging/tutorials/basics.md:76` back to `option+i`, ran the suite, and it failed with "basics.md:76 teaches sub-chat creation on the wrong key". Then I restored the file. Two Minor items remain:
- One history comment in `lua/parley/init.lua:2472` still says `<M-b>` where it means the old key.
- The new tutorial spec doesn't read README.md or the in-repo copies of the tutorials.

Neither blocks shipping.

**1. Strengths**
- Config and registry agree: `config.lua:426,432` match `keybinding_registry.lua:571,601`. The registry comment explains why changing only the registry would have no effect.
- The tutorial spec (`keybinding_agreement_spec.lua:673-725`) checks the action named after each key, not just that the key is bound. That is the check that catches `option+i` still being taught for branching now that `<M-i>` is bound to paste. It also has a guard (`seen > 10`) that fails if the pattern stops matching anything.
- The tutorial spec runs with the starter options, which is right because the tutorials ship with the starter app.
- History comments now use one form: `<M-i>` (now `<M-b>`). A grep for past-tense lines that mention `<M-b>` turns up only one miss (below).

**2. Critical** — none.

**3. Important** — none.

**4. Minor**
- `lua/parley/init.lua:2472` says "the caller then does what `<M-b>` did before M3". `<M-b>` wasn't bound before M3; this is the same history rewrite as BR-2. Fix it the way BR-2 was fixed.
- The tutorial spec reads only `packaging/tutorials/*.md` and the starter README. README.md:183 ("Alt+i … paste a clipboard image") and `workshop/parley/{welcome,basics,advanced}.md` also teach keys in prose, and nothing checks them. Add them to the spec's file list.

**5. Test coverage notes**
- `make test-spec SPEC=ui/keybindings` passes except for one test: `file_history_spec.lua:255` ("src Alt+o landing"). It expects `answer.md` and gets `session.md`. This diff doesn't touch that code: the only `init.lua` change is a comment, and `file_history.lua` is unchanged. It looks like an environment problem with resolving the `src:` root inside the review checkout, not a regression from this change. The implementer should still confirm it passes in their own worktree.
- BR-3's new assertion only adds coverage; no behavior fix depended on it.

**6. Architectural notes**
- **ARCH-DRY:** pass. The key is defined in config, with a matching registry fallback that its comment documents. The spec reads keys through `reg.resolve_keys` instead of copying them.
- **ARCH-PURE:** pass. Apart from the key values in config and the registry, the diff only changes comments, docs and tests.
- **ARCH-PURPOSE:** pass, with the gaps noted under Minor. Code, atlas, README and the shipped tutorials all use the new keys, and the tutorials are now checked against the registry.

**7. Plan revision recommendations** — none. The plan matches the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      All listed sites fixed (packaging/tutorials basics.md:76 and advanced.md:126, starter README:67, workshop/parley welcome/basics/advanced). The new spec at keybinding_agreement_spec.lua:673 goes red when basics.md:76 is reverted to option+i (checked by mutation).
  - id: BR-2
    disposition: addressed
    note: |
      All seven named sites now say "<M-i> (now <M-b>)". The one remaining stale history comment, init.lua:2472, is a separate Minor below.
  - id: BR-3
    disposition: addressed
    note: |
      keybinding_agreement_spec.lua:281 now also asserts <M-b> is absent under default_keymaps=false. This is test-only, so no behavior revert applies.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: history-notes-rewritten
    title: |
      init.lua:2472 says <M-b> did something before M3, but <M-b> was not bound then
    detail: |
      This is the 2nd finding in family history-notes-rewritten. The rule: a comment that describes past behaviour (did, was, used to, before Mn, hardcoded) keeps the key that was bound at the time and adds "(now <M-b>)". Sweep check: git grep -n '<M-b>' -- lua tests atlas | grep -Ei 'did|was|used to|before|hardcod|were'. In this window that grep hits seven lines; every one except init.lua:2472 is either correct or present-tense, so init.lua:2472 is the whole remaining family.
  - id: new
    severity: Minor
    kind: defect
    family: key-remap-doc-sweep
    title: |
      Tutorial key spec reads only packaging docs, not README.md or workshop/parley tutorials
    detail: |
      This is the 2nd finding in family key-remap-doc-sweep. The rule: every file that teaches a key in prose must be in the spec's file list. All of them are correct today. Unchecked files: README.md (Alt+i at line 183), workshop/parley/welcome.md:15, workshop/parley/basics.md:61,72, and workshop/parley/advanced.md:63,139. Add them to the file list at keybinding_agreement_spec.lua:684-685.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"83cd24d2-92f8-4122-8af6-90b7a7e35b68","repository":"github.com/xianxu/parley.nvim","issue_id":"000377","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/f148790c96a8508c","reviewed_head":"131c684c6ca6fde3af69e7fb119e31c9c523510f","slot":"parley.nvim:4","requested_at":"2026-10-17T20:44:56.255852Z"},"phase":"finished","pid":21320,"started_at":"2026-10-17T20:44:56.435532Z","finished_at":"2026-10-17T20:50:06.981024Z","session_id":"66409077-9160-4053-a678-a9d59064d116","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T13:53:25-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 377 — Remap keys: Alt+i pastes an image (matching pair draft), Alt+b creates a sub-chat |
| repo | parley.nvim |
| issue file | workshop/issues/000377-remap-alt-i-image-alt-b-branch.md |
| boundary | whole-issue close |
| milestone | — |
| window | 8ae51687b7b5f627604ab326f421505b6ec0423b..0342dddacf2bd79268ec0c437ab515d28a5eddb3 |
| command | sdlc close --issue 377 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T13:53:25-07:00 |
| verdict | SHIP |

## Review

Running the keybinding agreement spec to check that the widened file list passes.

```verdict
verdict: SHIP
confidence: high
```

Both open findings are fixed. The change since the last review touches two files with seven lines changed, adds no new scope, and leaves the Spec, Revisions and Done-when sections alone. The keybinding agreement spec passes in the isolated harness (36 passed, 0 failed). I also broke the docs on purpose to check that the wider file list really reads the new files. Changing `basics.md:61` to `Option+i` made the test fail with "teaches sub-chat creation on the wrong key". Changing `README.md:183` to `Alt+z` made it fail with "teaches <M-z>, which nothing binds". Both edits were reverted and the checkout is clean.

1. **Strengths**
   - BR-4 is fixed by the rule the finding stated, not just at the one line. I re-ran the sweep grep (`git grep -n '<M-b>' -- lua tests atlas | grep -Ei 'did|was|used to|before|hardcod|were'`). Every past-tense hit now names `<M-i>` and adds "(now `<M-b>`)" (`branch_submit.lua:22`, `branch_child_spec.lua:4`, `branch_submit_spec.lua:146`, `drill_in.md:166`, `inline_branch_links.md:54`, `init.lua:2472`). The other hits are present tense.
   - BR-5 is fixed by a glob (`workshop/parley/*.md`) instead of naming files one by one. A tutorial added later is checked automatically, which handles the whole class (ARCH-PURPOSE: pass).
2. **Critical:** none.
3. **Important:** none.
4. **Minor:** none new.
   - The `workshop/parley/*.md` glob also picks up the dated chat transcripts in that folder. None of them contains an Alt/Option-plus-letter key today, so this is harmless. If a future transcript quotes an unbound key, the test would fail. I'm noting this only; it is not a finding.
5. **Test coverage:** The two mutations above show the widened scan covers README.md and the in-repo tutorials. It checks both that each key is bound and that the image-paste and sub-chat lines name the right key.
6. **Architecture:**
   - **ARCH-DRY: pass.** `vim.list_extend` reuses the existing scan loop; nothing is duplicated.
   - **ARCH-PURE: pass.** The change is a comment and a test-only file list, with no new IO mixed into logic.
   - **ARCH-PURPOSE: pass.** Both fixes cover the whole family named in the findings.
7. **Plan revisions:** none.

```findings
dispose:
  - id: BR-4
    disposition: addressed
    note: |
      init.lua:2472 now reads "`<M-i>` (now `<M-b>`) did before M3"; the sweep grep shows every past-tense hit follows the rule.
  - id: BR-5
    disposition: addressed
    note: |
      The spec now globs workshop/parley/*.md and adds README.md. Mutating basics.md:61 and README.md:183 each turned the test red; the clean run passes 36/0.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"36a19d47-50e7-410d-a40b-9d8853286105","repository":"github.com/xianxu/parley.nvim","issue_id":"000377","recipe":"fix-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/9fd9a3e675f77312","reviewed_head":"0342dddacf2bd79268ec0c437ab515d28a5eddb3","slot":"parley.nvim:4","requested_at":"2026-10-17T20:52:02.512405Z"},"phase":"finished","pid":86218,"started_at":"2026-10-17T20:52:02.724423Z","finished_at":"2026-10-17T20:53:24.635143Z","session_id":"bd014708-7538-43b1-ad4d-7b208420e193","outcome":"returned"}] -->
