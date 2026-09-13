# Boundary Review — parley.nvim#237 (whole-issue close)

| field | value |
|-------|-------|
| issue | 237 — ParleyProxy update fetches the latest release unless pinned; status shows the version |
| repo | parley.nvim |
| issue file | workshop/issues/000237-proxy-update-latest.md |
| boundary | whole-issue close |
| milestone | — |
| window | 27bac4f4ba965e52f1026b0f1809036bbdfd41e4..d857e161cd948277bf4b342bab13c240e79310d5 |
| command | sdlc close --issue 237 |
| reviewer | claude |
| timestamp | 2026-09-12T17:37:34-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The four open Minors from rounds 4 and 7 are all delivered, and I verified each against the code rather than the close commit's message. Every spec the window touches is green in this shell, with the update spec's identity cases executing rather than pending. Conformance ran against the real 7.2.159 binary from the managed data dir and passed every #237 case, including the keyed and rejected version header, the lockout with its `error` body field, and both chat routes. The BR-16 driver is real: with the old Anthropic alias restored in a scratch copy, the recovery case and the unit pin both go red. The full gate reports 211 of 212 spec files passing. The one failure is `fold_invariants`, which reads a transcript the operator deleted in the worktree, and that deletion is not part of this window. Nothing blocks the close.

**Evidence run in this shell**

| Check | Result |
|---|---|
| cliproxy_release unit | 50/0 |
| cliproxy_auth unit | 78/0 |
| dispatcher unit | 65/0 |
| cliproxy_update integration | 40/0, none pending |
| recovery_e2e, lifecycle, login, download, command | 6/0, 53/0, 13/0, 6/0, 17/0 |
| conformance on real 7.2.159 | 10/2, the 2 are the pre-existing #205 catalog cases |
| revert of the claude route in a scratch copy | recovery_e2e 5/1, dispatcher 64/1 |
| arch specs | all pass except scratch_placement, which needs the XDG variables `make test` exports |
| make lint | 0 warnings in 372 files |
| make test JOBS=4 | 211/212, fold_invariants fails on the operator's uncommitted deletion |

## 1. Strengths

- **The decision surface is pure and fully pinned.** `lua/parley/cliproxy_release.lua` holds parsing, comparison, identity, the update table, the restart outcome and the status line with no IO, and its 50 unit cases run without mocks. The IO in `cliproxy.lua` is thin wrappers feeding it plain values.
- **The fake is stateful where the real binary is.** `tests/fixtures/fake_cliproxy` keeps the management failure counter, the SIGTERM exit delay and the GET delay, and the release fake keeps its state in a directory the spec owns with a request log. The conformance spec pins each modelled behaviour on the real binary, and those pins pass on 7.2.159 today.
- **Outcome messages claim only what was observed.** `restart_outcome` is fed by a post-restart probe, `running_identity` returns a reason instead of a guess, and `restart_managed` reports a proxy that outlives the port wait rather than reusing it. The slow-exit interleaving is reproduced by a 4 s fake and asserted at `cliproxy_update_spec.lua:486`.
- **The untrusted inputs are parsed at the boundary.** The redirect, the header, the version record and the config pin all go through `parse_version`, and the download URL is built only from the parsed value. `cliproxy_download_spec.lua` refuses `../../evil` by test.
- **Docs kept pace.** README, atlas intro, the atlas Testing and Versions sections, the config comment, the `:ParleyProxy` help and the traceability map all describe the new behaviour, and the command spec pins the help text.

## 2. Critical findings

None.

## 3. Important findings

None.

## 4. Minor findings

None new. The two conformance failures on the real binary are the #205 catalog cases, which predate this issue and are recorded in the Log with a follow-up.

## 5. Test coverage notes

- The `ps`-dependent identity cases executed here through `tests/fixtures/fake_ps`, so the six pins from rounds 2 and 3 ran rather than went pending.
- The BR-16 driver was verified by reverting: only the route constant changed, and both the integration case and the unit pin turned red.
- The BR-20 pin was verified live: the real 7.2.159 ban body carries the `error` string the conformance case now asserts.
- The mid-stream port-release timing of the real binary remains unmeasured, as the Log states. The failure mode is an honest error rather than a reused proxy, so this is a follow-up, not a gap in this window.
- Running a spec outside `make test` fails the scratch_placement arch spec and, in a fresh checkout, cannot boot without the gitignored generated vocabulary file. Both predate this window and are harness matters.

## 6. Architectural notes

- **ARCH-DRY: pass.** One version grammar, one target rule shared by `update` and first-run, one restart sequence for all four callers, one `NO_BINARY` text, one `ps` parser, one `await` helper.
- **ARCH-PURE: pass.** Every decision is in the pure module; `cliproxy.lua` gained only wrappers. The `run` helper makes sync and async share one path.
- **ARCH-PURPOSE: pass.** Every Done-when is delivered and tested, the discovered scope was swept as a class in each round, and the operator's live check confirmed a Fable chat through 7.2.159.
- **ARCH-MOCK: pass.** Both external dependencies have stateful fakes behind the production seam, and the conformance spec compares the modelled behaviour with the real binary and, opt-in, the real redirect.
- **ARCH-CONSTRAINTS: pass.** The envelope is explicit, the blocking fetch is an accepted operator choice, status is fully async with one callback, and the lockout budget is now a declared row.
- **ARCH-SECURE: pass.** Untrusted inputs are typed at the boundary, the test URL seam is gated on the harness flag, the management key goes to the same destination it already went, and the recursive delete is confined to a constructed leaf.
- **ARCH-ORDER: pass.** `update` has a written state table, a single-answer guard, a deadline owner and an in-flight guard; the status join has per-leg delay seams so any leg can land last. For upcoming work: the 20 s deadline timer is not cancelled after an early answer, which is harmless but would matter if the deadline ever became long.

## 7. Plan revision recommendations

None. The Core concepts tables match the code, the checkboxes are ticked through Task 13, and the Revisions already carry the lockout, the route change and the conformance download.

```findings
dispose:
  - id: BR-13
    disposition: addressed
    note: |
      atlas/providers/cliproxy-managed.md:447-450 now says the identity cases run in every shell and names fake_ps, PARLEY_FAKE_PS_ROWS and _set_process_tools; the old "report pending" phrase survives only in the conformance sentence, where it is true.
  - id: BR-16
    disposition: addressed
    note: |
      Reverting CLIPROXY_ANTHROPIC_ROUTE to the old alias in a scratch copy turns the recovery case red (5/1, HTTP 404 instead of 503) and the dispatcher pin red (64/1); the driver posts through the fake over HTTP.
  - id: BR-20
    disposition: addressed
    note: |
      cliproxy_conformance_spec.lua now decodes the 403 body and asserts decoded.error is a string containing "banned"; it passed live on 7.2.159 in this shell.
  - id: BR-21
    disposition: addressed
    note: |
      Plan line 288 names the lockout counter, the POST 404 rule and the GET delay on the fake_cliproxy row; line 264 adds the auth_files modified row; line 263 says version_probe is keyed.
```
