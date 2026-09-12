# Boundary Review — parley.nvim#237 (milestone M1)

| field | value |
|-------|-------|
| issue | 237 — ParleyProxy update fetches the latest release unless pinned; status shows the version |
| repo | parley.nvim |
| issue file | workshop/issues/000237-proxy-update-latest.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 27bac4f4ba965e52f1026b0f1809036bbdfd41e4..615dd8a1333dcb3656ab45718c8f62efd54f4e14 |
| command | sdlc milestone-close --issue 237 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-12T12:21:01-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

**Operator notice first.** While setting up the review I ran a `git checkout <head> -- .` where I meant `git diff`. That discarded two uncommitted worktree changes that were not part of this review: your unstaged edit to `workshop/parley/2026-09-09.11-40-59.150_astrophotography-plan.md` is gone (no swap file exists; if that buffer is still open in nvim, `:w` will restore it), and the deleted `workshop/parley/2026-09-10.11-10-24.522.md` was restored as a tracked file (its untracked rename to `..._lens-dovetail-mounting.md` is intact, so just delete the old one again). Nothing under `lua/`, `tests/`, `atlas/` or the issue/plan was affected; those matched head already. I made no further writes.

**Summary.** M1 delivers what the Spec and Plan Tasks 1–8 (+10) promise, and I verified it by running the code, not by reading the log: lint 0/0, the release unit spec 42/0, auth 78/0, download 6/0, command 14/0, lifecycle 53/0, the arch symbol check 21/0, the update spec 26/0 with the three `ps`-dependent identity cases genuinely executing in my direct run, and the mapped `providers/cliproxy-managed` group exit 0 (there the identity cases went `pending` because `ps` was refused in that shell, as the Log warns). No fixtures were orphaned after the runs. `PINNED_VERSION` is gone with no stale callers in `lua/`, `tests/` or README. The one thing to fix before crossing is documentation: `:ParleyProxy update` changed meaning and `download_version` became the pin, and README's only line on the subject still implies a brew-first install with `update` as an opaque subcommand. Everything else is Minor.

**1. Strengths**
- `lua/parley/cliproxy_release.lua` is a real pure core: every decision (target, refusal, install/restart, message text) is a table-in/table-out function, and `tests/unit/cliproxy_release_spec.lua` exercises it with zero IO. `plan_update` is the single place that decides and words the outcome.
- `tests/helpers/fake_releases.lua` + `tests/fixtures/fake_github_releases` is a stateful double behind the same URL seam production uses (`releases_url()`), with a request log the specs assert on ("no `/download/` when already current", "no `/latest` when pinned"). That is exactly what ARCH-MOCK asks for.
- Failure atomicity is tested by inode, not by prose: `cliproxy_update_spec.lua` "changes nothing when GitHub cannot be reached" / "…fails its checksum" compare `fs_stat(bin).ino` before and after and re-read the version record.
- `tests/minimal_init.vim` pointing `$PARLEY_CLIPROXY_RELEASES_URL` at port 9 plus the `harness` case that asserts the flag was actually seen (the #227 lesson) makes a forgotten seam fail fast instead of touching github.com.
- `M.update` in `lua/parley/cliproxy.lua` has a clean terminal-ownership story: `finish` is idempotent, the guard is released before `cb` runs, the whole sequence is under `pcall`, and the deadline is proven by a test with an injected never-answering `restart_managed`.
- `download({ version = "../../evil" })` is refused before any URL is built (ARCH-SECURE, tested).

**2. Critical findings** — none.

**3. Important findings**
- `README.md:221` — README update appears missing for the changed `update` surface. The line lists `update` among subcommands and tells a fresh install to expect `brew install cliproxyapi`, while this diff makes `update` install the latest release (or the `download_version` pin) and restart parley's own proxy, and `config.lua` already ships `auto_download = true`. Fix sketch: one sentence after the subcommand list, e.g. "`update` installs the newest cliproxyapi release, or `cliproxy.download_version` when set, and restarts the proxy parley launched; with `auto_download` on, the first run installs the same target so `brew install` is optional."

**4. Minor findings**
- `lua/parley/cliproxy.lua:1841` (`releases_url()`): a test seam reaches production. `$PARLEY_CLIPROXY_RELEASES_URL` redirects both the latest lookup and the binary download (checksums included) and is absent from the plan's Trust boundaries table. Either gate it on `$PARLEY_TEST_MODE` or list it as a supported override in the trust table and atlas.
- `lua/parley/cliproxy.lua:2087` + `init.lua:376`: when `plan.restart == "manual"` the update returns `ok = true`, so "…was not started by parley and still runs 7.1.71; stop it…" is shown at INFO. WARN level would match the outcome.
- `cliproxy_release.lua` `plan_update`: a non-cliproxy process on the port (which `version_probe` reports as `no_header`, not `down`) yields the "brew services stop cliproxyapi" hint. `ensure_running` already names that case "held by a non-cliproxy process"; consider carrying the health state into `running` so the message can say so.
- ARCH-DRY (tests): `await` is now copy-pasted in three specs (`cliproxy_update_spec.lua`, `cliproxy_lifecycle_spec.lua`, `cliproxy_login_spec.lua`); `spawn_fake`/`reap` are near-duplicates too. `tests/helpers/` is the home.
- Plan tracking: 0 of 68 step checkboxes in `workshop/plans/000237-proxy-update-latest-plan.md` are ticked while the Log claims Tasks 1–8 done. Tick the M1 steps at close.
- `init.lua:375`: the "finding the release to install…" notify precedes a synchronous fetch, so it usually renders only after the blocking call returns (pre-existing pattern, now on a longer path).

**5. Test coverage notes**
- Covered well: target rule (pin vs latest, request-log proofs), atomic install, checksum refusal, unknown record, refusals before network, second-update guard, deadline release, first-run auto_download both ways, `:ParleyProxy` glue.
- Not covered: the `restart_managed` on_error transition in `M.update` ("…the restart failed — …"). Cheap to add by stubbing `restart_managed` to call its second argument. Also `port_identity`'s `lsof`/`ps`-unavailable degradation is only covered indirectly via the empty-rows unit case.
- Environment caveat: the three restart-ours cases silently become `pending` wherever `ps` is refused, which includes the mapped `make test-spec` run in this session. A close should cite a run where they executed (my direct run did).
- ARCH-MOCK: live conformance for the redirect (`PARLEY_LIVE_GITHUB=1`) and for the real binary's header with management disabled are scheduled in M2 Task 13; until then `update` relies on the 2026-09-11 hand verification.

**6. Architectural notes (ARCH-* lenses)**
- ARCH-DRY: pass in production code (one version grammar, one `ps` grammar via `parse_ps`, `api_argv` reused with `dump_headers`, one target rule for update and first-run). Flag only on test helpers, above.
- ARCH-PURE: pass. The IO shell is thin; `update` is orchestration over pure `plan_update`.
- ARCH-PURPOSE: pass for M1. The deferred parts (status version text wiring, `managed` label, live checks) are the plan's M2, not the point of this milestone.
- ARCH-MOCK: pass with the deferral noted above.
- ARCH-CONSTRAINTS: pass. I checked the constants: `PORT_RELEASE_MS` 2 s + `POLL_BUDGET_MS` 5 s + probe `--max-time` 2 s legs stay under the 20 s deadline; latest lookup is bounded at 5/10 s; the synchronous fetch is an operator-accepted choice recorded in the Log.
- ARCH-SECURE: pass, one Minor (env override). Versions are parsed before entering a URL, the probe sends no credential, the record and redirect are strict-parsed to unknown.
- ARCH-ORDER: pass. The legal transitions of `update` are the plan's table and the code follows it; two orderings (second update, never-answering restart) have seams and tests. The untested `restart failed` cell is the only gap.
- For M2: `M.status` still reports a managed-dir binary as `"PATH"` (`cliproxy.lua:876`); Task 12 owns it.

**7. Plan revision recommendations**
- None required; the Core-concepts tables match the code for M1. The `status | modified` integration row is M2 work and should stay as is.

```findings
findings:
  - id: new
    severity: Important
    family: readme-surface-drift
    title: |
      README does not describe the changed :ParleyProxy update semantics or the download_version pin
    detail: |
      README.md:221 lists `update` bare and still says a fresh install should expect `brew install`; the diff makes update install the latest release or the download_version pin and restart parley's proxy, and auto_download is on by default. One sentence fixes it.
  - id: new
    severity: Minor
    family: test-seam-in-production
    title: |
      $PARLEY_CLIPROXY_RELEASES_URL redirects production downloads and is absent from the trust table
    detail: |
      releases_url() in cliproxy.lua honours the env var outside tests; gate it on PARLEY_TEST_MODE or document it as a supported override in the plan's Trust boundaries and the atlas.
  - id: new
    severity: Minor
    family: outcome-severity
    title: |
      A manual-restart outcome is reported as ok=true and shown at INFO
    detail: |
      plan_update's restart="manual" path means the proxy still serves the old version; init.lua notifies the message at INFO because update() returned ok=true.
  - id: new
    severity: Minor
    family: message-provenance
    title: |
      A non-cliproxy port holder gets the "brew services stop cliproxyapi" hint
    detail: |
      version_probe reports no_header (not down) for any HTTP server on the port, so plan_update words it as a foreign cliproxy; ensure_running already distinguishes that case.
  - id: new
    severity: Minor
    family: test-helper-duplication
    title: |
      await, spawn_fake and reap are copy-pasted across three cliproxy specs
    detail: |
      cliproxy_update_spec adds a third `await`; tests/helpers is the home (ARCH-DRY on the test side).
  - id: new
    severity: Minor
    family: error-path-coverage
    title: |
      update's "the restart failed" transition has no test
    detail: |
      Stub restart_managed to call its on_error and assert the message and released guard; the never-answers and second-update orderings are covered, this cell is not.
  - id: new
    severity: Minor
    family: plan-checkbox-tracking
    title: |
      No plan step checkboxes are ticked although Tasks 1–8 are logged as done
    detail: |
      0 of 68 `- [ ]` rows in the plan are ticked; tick the M1 steps at milestone close.
```
