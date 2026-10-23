# Boundary Review — parley.nvim#423 (whole-issue close)

| field | value |
|-------|-------|
| issue | 423 — Long TMPDIR makes nvim tempname() fall back outside the test scratch |
| repo | parley.nvim |
| issue file | workshop/issues/000423-long-tmpdir-makes-nvim-tempname-fall-back-outside-the-test-scratch.md |
| boundary | whole-issue close |
| milestone | — |
| window | a2dca3b56fd352edee6601eab68c6e88b2b6d4d7..3f63c3b3a684d4452287b5e0619fb89e903e9012 |
| command | sdlc close --issue 423 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-23T04:45:37-07:00 |
| verdict | REWORK |

## Review

I'm running the changed spec, then checking the edge cases I found: how the guard counts non-ASCII lengths, and how long the test base path can get.

Spec passes here; the two failures elsewhere are census tests that need `ps`, which this environment lacks. Next I'm checking whether an accepted long root breaks the new guard spec.

```verdict
verdict: REWORK
confidence: high
```

The pieces are right, but the new length check breaks the guard's own tests in setups the guard accepts. The guard (`scripts/test-placement.sh`) refuses a root whose `/tmp` is over 189 bytes, and the spec reads that limit from the script and checks it against the running Neovim. The in-process check that `tempname()` stays under `$TMPDIR` is also sound. The problem is where the length check sits: it runs before the marker and checkout checks. The older #422 guard tests build their fixture roots about 70 bytes deeper than the harness TMPDIR. So any harness TMPDIR of roughly 120–189 bytes passes the guard, yet the suite fails. Long paths like that are exactly the setup #422 and #423 were written for.

I reproduced this with `make test-spec SPEC=infra/test_harness TEST_ENV_ROOT=<171-byte path>`. All six "pre-write placement guard" cases fail, and the marker and checkout refusals are replaced by the length message. This review checkout's default root is 114 bytes, so its marked-tree fixture comes to 187 bytes and passes with only 2 bytes to spare. On the default root the spec passes 19/0/0 on 0.11.7. The only failures in that run were two process-census specs outside this diff, which can't count processes without `ps`.

**1. Strengths**
- `scratch_placement_spec.lua:238-243`: the spec reads `TMPDIR_MAX` from the script, so the limit is defined in one place (ARCH-DRY pass).
- `scratch_placement_spec.lua:251-265`: a pin test runs a real child Neovim at 189 and 190 bytes, so a change in Neovim's limit fails loudly instead of drifting.
- `scratch_placement_spec.lua:40-47`: the in-process check tests the path `tempname()` actually returns, so it catches a fallback for any reason, not just length.
- The refusal message names the length, the limit and the fix, and the test checks that nothing is created.

**2. Critical**
- **`scripts/test-placement.sh:31-37`: the length check comes before the #422 checks and breaks the guard's own tests on accepted roots.**
  - The fixtures at `scratch_placement_spec.lua:195-226` are `base/clone/.sdlc-review/tmp/parley-test-env/key`, `base/checkout/.test-env`, `base/scratch/...`, and so on. `base` is `TMPDIR/nvim.<user>/XXXXXX/N`.
  - With a 171-byte root (accepted by the guard), every guard case fails.
  - Every refusal is masked the same way: "under a marked tree" and "inside the checkout" both report the length message instead.
  - **Fix sketch:**
    - Move the length check after the marker/checkout walk, so the #422 reasons take precedence.
    - Make the fixture roots short. For example, call the guard with `cwd = base` and pass relative roots such as `clone/.sdlc-review/...`. The script measures the raw `$root/tmp` string and already resolves relative paths through `cd`.
    - `path_of` (`:229-234`) has the same family. Once `base` is longer than about 184 bytes it fails with a bare `assert`, which happens when the harness TMPDIR is about 163–189 bytes. The relative-path or `cwd` approach covers it too, or else skip with a clear reason.

**3. Important**
- **`scripts/test-placement.sh:32`: `${#tmp}` counts characters, not bytes.** macOS `/bin/sh` is bash; under a UTF-8 locale `x=éé; ${#x}` gives 2, not 4. A non-ASCII root over 189 bytes would pass the guard and print a wrong "N bytes". The in-process check still catches it, but only after other specs have run. **Fix:** use `printf %s "$tmp" | wc -c`, or set `LC_ALL=C` before the expansion (both checked here: 4). Add a non-ASCII case to the guard test.

**4. Minor**
- The "is X under Y" prefix check is now written three times (`:27`, `:45`, `:262`); a small `is_under(dir, path)` helper would cover all three (ARCH-DRY, minor).
- In the over-limit case, the pin test's child Neovim falls back to `/tmp/nvim.<user>`. Where a sandbox denies `/tmp`, that child fails in a way the test doesn't explain; it only reports `false`.

**5. Test coverage**
- Both 189/190 sides are covered for the guard and for the pin.
- No test runs the guard specs with a harness root near the limit; that gap let the Critical through. The plan's "Live" check used only the normal checkout plus an over-limit root.
- There is no non-ASCII case.
- I could only check 0.11.7 here, where the pin passes.

**6. Architecture**
- ARCH-DRY: pass (limit defined once; minor helper note above).
- ARCH-PURE: pass. The guard is thin shell glue and the check is a simple comparison.
- ARCH-PURPOSE: flag. The purpose is a harness that works under long scratch paths, and this diff makes the guard's own spec fail across most of the length range it accepts.
- ARCH-EVOLVE: pass. No persisted formats change.

**7. Plan revisions**
- Add to `## Revisions`: the length check runs after the #422 marker/checkout walk; the guard fixtures use short or relative roots so they pass at any accepted harness TMPDIR length; the length is counted in bytes.
- Add a test item: the guard spec passes with a `TEST_ENV_ROOT` near the limit (`/tmp` at about 185 bytes).

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: guard-fixture-length-budget
    title: |
      Length check runs before the 422 checks; guard specs fail on roots the guard accepts
    detail: |
      scripts/test-placement.sh:31-37 runs the TMPDIR length refusal before the marker/checkout walk. The fixture roots in tests/arch/scratch_placement_spec.lua:195-226 are about 70 bytes longer than the harness TMPDIR. Reproduced: make test-spec SPEC=infra/test_harness TEST_ENV_ROOT=<171-byte path> fails all six pre-write guard cases, and the marker and checkout refusals are masked by the length message. The default root of this checkout passes with 2 bytes to spare. Same family: path_of at :229-234 asserts (bare assert) once base is longer than about 184 bytes. Fix: move the length check after the walk, and make the fixtures short or relative (vim.system cwd=base, relative roots) so they hold at any accepted root length.
  - id: new
    severity: Important
    kind: defect
    family: byte-vs-char-length
    title: |
      test-placement.sh counts characters, not bytes, so a non-ASCII root over the limit passes
    detail: |
      scripts/test-placement.sh:32 uses the ${#tmp} expansion. macOS /bin/sh is bash and counts characters under a UTF-8 locale (verified: éé gives 2). Neovim's limit is in bytes, so a non-ASCII TEST_ENV_ROOT over 189 bytes passes the pre-write guard and prints a wrong byte count. Fix: printf %s "$tmp" | wc -c, or set LC_ALL=C before the expansion. Add a non-ASCII guard case.
  - id: new
    severity: Minor
    kind: defect
    family: path-containment-helper
    title: |
      The is-under prefix check is written three times in scratch_placement_spec
    detail: |
      Lines 27, 45 and 262 each write sub(1, #dir+1) == dir .. "/". Extract an is_under(dir, path) helper (ARCH-DRY).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"8b505bf7-c68d-49f2-96ec-fe8e48b45e31","repository":"github.com/xianxu/parley.nvim","issue_id":"000423","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/b81687d11e46cbd5","reviewed_head":"3f63c3b3a684d4452287b5e0619fb89e903e9012","slot":"parley.nvim:1","requested_at":"2026-10-23T11:38:02.232548Z"},"phase":"finished","pid":23957,"started_at":"2026-10-23T11:38:02.395336Z","finished_at":"2026-10-23T11:45:35.854935Z","session_id":"6f3c9f0a-2c45-42cd-8b1c-ee9d1ea1f71b","outcome":"returned"}] -->

---

## Re-review — 2026-10-23T05:13:32-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 423 — Long TMPDIR makes nvim tempname() fall back outside the test scratch |
| repo | parley.nvim |
| issue file | workshop/issues/000423-long-tmpdir-makes-nvim-tempname-fall-back-outside-the-test-scratch.md |
| boundary | whole-issue close |
| milestone | — |
| window | a2dca3b56fd352edee6601eab68c6e88b2b6d4d7..f0e50f6edcf4b76e2fe2655ec20587f0e61c0b08 |
| command | sdlc close --issue 423 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-23T05:13:32-07:00 |
| verdict | SHIP |

## Review

Checking how the Makefile passes TEST_ENV_ROOT/TMPDIR, then running the specs.

Prior-finding fixes pass at the default root. Next I'm checking BR-1 at a long root and reverting the fixes to confirm the tests go red.

```verdict
verdict: SHIP
confidence: high
```

All three prior findings are fixed, and I checked each fix by running the tests rather than trusting the commit messages. At the default root (70-byte outer TMPDIR, Neovim 0.11.7), every #423 case in `scratch_placement_spec` passes. They also pass at a 185-byte `TEST_ENV_ROOT`, which gives a `ROOT/tmp` of exactly 189 bytes, the longest root the guard accepts. That is the case BR-1 broke. I then reverted both fixes in `scripts/test-placement.sh`: I put back `${#tmp}` and moved the length check ahead of the marker walk. Exactly two cases went red: "counts the TMPDIR limit in bytes" and "reports a marker before the TMPDIR length". I restored the file and the checkout is clean.

Two other suite failures show up at both roots and during the revert run: the process census and the `test_run_lease` live census. They come from this review sandbox, where `ps` is not permitted and spawning returns EPERM. They have nothing to do with #423. I could only run 0.11.7 here, so the 0.12.5 measurement rests on the implementor's log and the pin test running in the suite's compat pass. One new Minor finding.

1. **Strengths**
   - `scratch_placement_spec.lua:233-238`: `limit()` reads `TMPDIR_MAX` out of the guard script itself, and the pin case at :274-292 checks it against the running Neovim at both 189 and 190. The constant has one home and can't drift without a test failing (ARCH-DRY pass).
   - Making the fixtures relative (`vim.system` with `cwd = base`) fixes the whole fixture-length family, not just the cases BR-1 named. The nested lease roots in `test_run_lease.py:97,438` were swept in the same change. This held at the longest accepted root.
   - The in-process check (:45-52) asserts where `tempname()` actually lands, not the constant. That catches fallbacks with other causes too.
   - The byte count `LC_ALL=C wc -c` (`test-placement.sh:47`) is checked by a non-ASCII fixture with 97 characters and 190 bytes, and that fixture goes red without the fix.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `scripts/test-placement.sh:44-52`: the guard only measures the raw `ROOT/tmp` string. The spec comment at :275-277 notes Neovim's second limit, on the absolute path (about 234 bytes). A relative `TEST_ENV_ROOT` that is short but resolves somewhere deep therefore passes the guard.
     - I probed this with `TMPDIR=t` under a 240-byte cwd. `tempname()` returned a truncated `…/t/nvim.xianxu/` with no file part. It did not fall back to `/tmp`.
     - Its `:h` still lies under `$TMPDIR`, so the in-process check would pass too.
     - The default harness root is absolute, which is why this is Minor. The guard's own header comment ("Neovim uses $TMPDIR only while the string is at most TMPDIR_MAX bytes") states only half of the rule.
     - Fix: either make `ROOT` absolute before measuring, or document that the guard assumes an absolute root.
     - This is the only instance in the window.

5. **Test coverage**
   - Both sides of each boundary are tested: 189 passes and 190 refuses; the pin probe checks used(189) and !used(190).
   - Both states of "creates nothing" are asserted.
   - The marker-before-length ordering has its own case.
   - The in-process assertion has no direct negative case, because the guard blocks that state before a run starts. The pin probe covers the mechanism instead. That is acceptable.

6. **Architecture notes**
   - ARCH-DRY: pass. The `is_under` helper was extracted, and the limit has a single source.
   - ARCH-PURE: pass. The new code is a thin shell guard plus spec assertions, and there is no business logic mixed with IO.
   - ARCH-PURPOSE: pass. Both clauses of `## Done when` are delivered: the limit was measured (pinned per version by the spec), and the harness fails once, up front, with the reason.
   - ARCH-EVOLVE: pass, not applicable. No persisted formats changed.
   - The atlas is updated (`atlas/infra/test_harness.md:67-71`). The README doesn't need a change, because `TEST_ENV_ROOT`/`TMPDIR` are existing surface.

7. **Plan revisions:** none required. Optionally, add a note to the Plan that the guard models only the raw-string limit, and that the absolute-path limit is unguarded for relative roots.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Reproduced fix: all guard and pin cases pass at a 185-byte TEST_ENV_ROOT (189-byte ROOT/tmp); moving the length check before the walk turns "reports a marker before the TMPDIR length" red.
  - id: BR-2
    disposition: addressed
    note: |
      Reverting to the ${#tmp} expansion turns "counts the TMPDIR limit in bytes, not characters" red (93 é = 190 bytes / 97 chars); restored and green.
  - id: BR-3
    disposition: addressed
    note: |
      is_under helper at scratch_placement_spec.lua:24-26 now serves the repo check, the in-process TMPDIR check and the pin probe.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: nvim-tmpdir-limit-model
    title: |
      Pre-write guard ignores Neovim's absolute-path limit, so a relative TEST_ENV_ROOT escapes it
    detail: |
      scripts/test-placement.sh:44-52 measures only the raw ROOT/tmp string. Neovim also limits the absolute path (about 234 bytes; the spec comment at :275-277 says so). Probe: TMPDIR=t under a 240-byte cwd gave a truncated tempname "…/t/nvim.xianxu/", and the in-process :h-under-TMPDIR check would also pass on it. Fix: make ROOT absolute before measuring, or document that the guard assumes an absolute root. This is the only instance in the window.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"47e99c73-bed1-4908-a823-43b2f1b757f0","repository":"github.com/xianxu/parley.nvim","issue_id":"000423","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/332d857b280cbfbf","reviewed_head":"f0e50f6edcf4b76e2fe2655ec20587f0e61c0b08","slot":"parley.nvim:1","requested_at":"2026-10-23T12:04:20.092404Z"},"phase":"finished","pid":50229,"started_at":"2026-10-23T12:04:20.221228Z","finished_at":"2026-10-23T12:13:30.948171Z","session_id":"1e8bf238-ea07-4c5f-90d8-883c09b98af7","outcome":"returned"}] -->
