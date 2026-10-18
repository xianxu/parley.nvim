# Boundary Review — parley.nvim#381 (whole-issue close)

| field | value |
|-------|-------|
| issue | 381 — review_protocol_export_test hardcodes /tmp for temp dirs (#342 rule) |
| repo | parley.nvim |
| issue file | workshop/issues/000381-review-protocol-export-test-hardcodes-tmp-for-temp-dirs-342-rule.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4ce9f053e48c7cf23dda4d394f9705a6c6e7d56e..74f9a4582ba9608a5bcd2648f6879951fb29b089 |
| command | sdlc close --issue 381 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T18:37:18-07:00 |
| verdict | SHIP |

## Review

Still reviewing: I'm running the new guard spec to confirm it passes at the pinned head.

Old make lacks `--eval`; I'll use a temp makefile outside the tree.

```verdict
verdict: SHIP
confidence: high
```

The fix does what the issue asks. All six fixed `dir='/tmp'` roots in `tests/unit/review_protocol_export_test.py` are gone; the code now omits `dir=`, so `tempfile` uses `TMPDIR` by itself. The one shell instance, `scripts/check-spell-compatibility.sh:10`, now uses `"${TMPDIR:-/tmp}"` and adds `|| exit 1`, like the sibling scripts. A new fitness guard stops the problem coming back.

I grepped every `/tmp` in tracked `tests/`, `scripts/` and `Makefile*`. Nothing roots a temp dir at a fixed `/tmp` any more. The remaining hits are of three kinds:
- the allowed fallbacks, `${TMPDIR:-/tmp}` and `os.getenv("TMPDIR") or "/tmp"`;
- path strings that never reach disk, such as fixtures, `cwd='/tmp'` and `expand_path` inputs;
- comments.

I ran the specs at the pinned head under the harness env:
- `review_protocol_bundle_spec` passes (1/1).
- The two new guard cases pass.
- With `dir='/tmp'` put back at `:308`, the scan case fails as it should. I then restored the file; the checkout is clean.

The other 8 cases in `scratch_placement_spec` failed in my run, but only because this review checkout sets `TMPDIR` inside the repo tree (`.sdlc-review/tmp`). That is the review environment, not a fault in this diff. Nothing blocks SHIP; there is one Minor note on how much the guard's patterns catch.

1. **Strengths**
   - `tests/arch/scratch_placement_spec.lua:111-124`: the fixture case tests both forms the guard refuses and both allowed fallbacks. It builds `"/" .. "tmp"` in pieces, so the guard does not flag its own source.
   - The guard lists files through `arch_helper.worktree_files` (`:106`), so it also sees untracked files. Its `#files > 50` floor stops an empty scan from passing silently.
   - The scan is a pure function, `fixed_tmp_roots(files)`, separate from where the file list comes from. It is tested on fixtures and on the real tree (ARCH-PURE: pass).
   - The atlas entry in `atlas/infra/test_harness.md:67-71` documents the new rule and the allowed fallback.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - The guard's two patterns (`scratch_placement_spec.lua:88-91`) only catch the exact forms that were swept. Spellings of the same class that would get past it:
     - Python `dir='/tmp/'` (trailing slash), `dir=Path('/tmp')`, `dir='/tmp/sub'`;
     - shell `mktemp -p /tmp …`, `mktemp --tmpdir=/tmp`;
     - Lua writes under a literal `/tmp`, which the plan's sweep covered but the guard does not scan.
     
     A broader Python pattern such as `dir%s*=%s*[%w_.]*%(?['\"]/tmp['\"/]` would catch the Python cases, and a `mktemp[^\n]-%-%-?[pt]%a*[=%s]['\"]?/tmp` alternative would catch the shell ones. Today the tree has none of these.

5. **Test coverage notes**
   - Both forms the guard refuses and both fallbacks are pinned by the fixture case.
   - The scan of the real tree goes red when the bug is put back; I confirmed this by mutation.
   - The second "Done when" clause (the bundle spec passes in a sandboxed shell) is backed by the implementer's log, and by my run, where the bundle spec passed.

6. **Architectural notes**
   - **ARCH-DRY: pass.** The guard reuses `arch_helper.worktree_files`, and the shell fix copies the sibling scripts' idiom.
   - **ARCH-PURE: pass.**
   - **ARCH-PURPOSE: pass.** The class was enumerated (7 instances), all were swept, and a guard enforces the rule, rather than only the one reported site being fixed.

7. **Plan revision recommendations:** none. The plan matches the code.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: fixed-tmp-temp-root
    title: |
      The fixed-/tmp guard only matches the exact spellings that were swept
    detail: |
      FIXED_TMP in tests/arch/scratch_placement_spec.lua:88-91 matches dir='/tmp' and mktemp ... /tmp/. It misses these spellings of the same class: Python dir='/tmp/' (trailing slash), dir=Path('/tmp'), dir='/tmp/sub'; shell mktemp -p /tmp and mktemp --tmpdir=/tmp; Lua writes under a literal /tmp, which the plan's sweep covered but the guard does not scan. The tree has none of these today. Broadening both patterns and adding one fixture line per spelling would close the gap.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"c1adf78d-20d4-4558-97dc-52518d8b7210","repository":"github.com/xianxu/parley.nvim","issue_id":"000381","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/46b50fb03b13ee79","reviewed_head":"74f9a4582ba9608a5bcd2648f6879951fb29b089","slot":"parley.nvim:4","requested_at":"2026-10-18T01:35:27.87627Z"},"phase":"finished","pid":81263,"started_at":"2026-10-18T01:35:27.96949Z","finished_at":"2026-10-18T01:37:17.665019Z","session_id":"aeb6da83-7251-49ab-9215-f79ead0d23c4","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T18:43:57-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 381 — review_protocol_export_test hardcodes /tmp for temp dirs (#342 rule) |
| repo | parley.nvim |
| issue file | workshop/issues/000381-review-protocol-export-test-hardcodes-tmp-for-temp-dirs-342-rule.md |
| boundary | whole-issue close |
| milestone | — |
| window | a15f10d013fc2d662459aeb9c2d4e8ad3a6162f7..105a962570783575e9bdd540b6e6cedb37547f06 |
| command | sdlc close --issue 381 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T18:43:57-07:00 |
| verdict | SHIP |

## Review

Running the guard spec at the pinned head to check the broadened patterns.

Still trying to run the guard spec through the make harness; next I'll find the right SPEC key.

```verdict
verdict: SHIP
confidence: high
```

The fix for BR-1 is in place. `FIXED_TMP` now catches every spelling the finding listed:
- Python: `dir='/tmp/'`, `dir='/tmp/sub'` and `dir=Path('/tmp')`.
- Shell: `mktemp -p /tmp` and `mktemp --tmpdir=/tmp`.
- Lua: writes to a literal `/tmp` through `io.open`, `mkdir` or `writefile`.

The fixture case covers each spelling with its own line. It counts the hits it expects, and it also checks that no allowed line is flagged: the `TMPDIR` fallbacks, and a `/tmp` that only appears inside content or a path suffix. I ran `make test-spec SPEC=infra/test_harness` at the pinned head. Both `/tmp` guard cases pass: the scan of the real tree and the every-spelling fixture case.

The other 8 cases in `scratch_placement_spec` fail in this checkout. That comes from the review environment: `TMPDIR` points inside the repo at `.sdlc-review/tmp`, which is the same thing the earlier review saw. It is not caused by this diff.

The window changes no Spec or scope; the only other changes are the generated gate and review records. I found one new Minor issue: the new per-language scoping narrows what the shell rules scan.

1. **Strengths**
   - `tests/arch/scratch_placement_spec.lua:132-161`: the fixture case is table-driven, with one line per refused spelling. It checks the hit count and also checks that every hit falls on a refused line, so a pattern that is too broad fails too, not just one that misses.
   - The `dir=` rule no longer falsely matches Lua path strings, because rules are scoped by language (`lang_of`, `:102-106`).
   - The scan is still the pure `fixed_tmp_roots(files)` function, tested separately from listing the files (ARCH-PURE: pass).

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `scratch_placement_spec.lua:102-114`: `lang_of` sends `.py` and `.lua` files only to their own language's rules. Before this change, every rule ran on every file. So a shell command inside Lua or Python is no longer checked, for example `vim.fn.system("mktemp -d /tmp/x.XXXXXX")` or `subprocess.run(["mktemp", "-p", "/tmp"])`. The tree has none of these today (`git grep mktemp -- '*.lua' '*.py'` only finds this spec).

5. **Test coverage notes:** every new pattern has a fixture line, so taking any one pattern out makes the expected count fail. Both guard cases pass under the harness at the pinned head.

6. **Architecture**
   - ARCH-DRY: pass.
   - ARCH-PURE: pass.
   - ARCH-PURPOSE: pass. The finding's whole list of spellings was swept in one round, not just the one site it named.

7. **Plan revision recommendations:** none.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Every listed spelling (py dir='/tmp/', '/tmp/sub', Path('/tmp'); sh -p, --tmpdir=; lua io.open/mkdir/writefile) now has a FIXED_TMP rule and a fixture line; both guard cases pass under make test-spec at the pinned head.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: fixed-tmp-temp-root
    title: |
      Language scoping stops the shell mktemp rules from scanning shell commands inside Lua or Python
    detail: |
      This is the 2nd finding in family fixed-tmp-temp-root. lang_of (scratch_placement_spec.lua:102-114) sends .lua and .py files only to their own language's rules. So vim.fn.system("mktemp -d /tmp/...") or subprocess mktemp -p /tmp now gets past the guard, though it was caught before this interdiff (prevalence today: 0 in the tree). The rule that covers the class: scope a pattern by file type only when it would otherwise give false positives (the Python dir= keyword). Shell command patterns stay unscoped, because those commands can appear inside any language. Add one fixture line for embedded mktemp.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"4124250a-7ed5-4eeb-9f5c-272df4f70272","repository":"github.com/xianxu/parley.nvim","issue_id":"000381","recipe":"fix-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/03d18069c602a4ab","reviewed_head":"105a962570783575e9bdd540b6e6cedb37547f06","slot":"parley.nvim:4","requested_at":"2026-10-18T01:41:14.08744Z"},"phase":"finished","pid":25545,"started_at":"2026-10-18T01:41:14.469804Z","finished_at":"2026-10-18T01:43:54.14943Z","session_id":"00e49820-77af-431d-8063-bad951c99124","outcome":"returned"}] -->
