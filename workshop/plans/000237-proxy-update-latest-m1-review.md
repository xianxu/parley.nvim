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

---

## Re-review — 2026-09-12T12:49:03-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 237 — ParleyProxy update fetches the latest release unless pinned; status shows the version |
| repo | parley.nvim |
| issue file | workshop/issues/000237-proxy-update-latest.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 27bac4f4ba965e52f1026b0f1809036bbdfd41e4..1a5905dd81a447586907ca28223c6a9b9f1a29dd |
| command | sdlc milestone-close --issue 237 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-12T12:49:03-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Everything I need is in hand. I'm writing up the review now.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

**Summary.** The round-1 fixes are real, not cosmetic, and I checked each against its pinning test rather than the commit message: the README, atlas, config comment and both "no binary" error strings now say `:ParleyProxy update` is the way in; the release-URL environment seam is gated on `$PARLEY_TEST_MODE` with a test that would fail without the gate; the manual-restart outcome carries `warn` end to end; the no-version port holder no longer gets the brew hint; `await`/`settle` live once in `tests/helpers/await.lua`; the "restart failed" cell has a case; and the 14 unticked plan steps are all in M2's Tasks 11–13. Runs in this session: lint 0/0, release unit 43/0, auth 78/0, download 6/0, command 15/0, login 13/0, lifecycle 53/0, arch sweep green, update spec 29/0 with **4 pending** — `ps` is refused in this shell (EPERM even for `/bin/ps`, also from inside nvim), so the four identity-gated cases, including the new BR-6 case, went pending here and I verified them by reading, not by execution. Confidence is medium for that reason only. What keeps this from SHIP is one Important repeat of the `message-provenance` family: BR-4 fixed the instance, but two sibling sites still assert facts the call never observed, and one of them is the Spec's own Done-when ("the proxy serving requests is the new binary").

**1. Strengths**
- `lua/parley/cliproxy.lua:1846-1855` — the env override is now read only under the harness signal, and the `harness` case in `cliproxy_update_spec.lua:63` proves both branches without contacting either URL. Trust boundaries and atlas say the same thing.
- `NO_BINARY` (`cliproxy.lua:19`) is the class fix for BR-1: one text, three callers, so the next "how does the binary arrive" change cannot drift again.
- `plan_update` (`cliproxy_release.lua:154-193`) remains the single place that decides and words the outcome; the new `warn` flag rides the same table, and `init.lua:376-382` maps `ok/warn` to ERROR/WARN/INFO with a command-spec case per level.
- The two "changes nothing" cases compare inodes and re-read the record; the checksum refusal is tested at the seam the real download uses.
- `tests/helpers/await.lua` exposes both `settle` (for specs asserting on the timeout themselves) and `await` (fails on timeout) — the right split, and each spec keeps its own budget.

**2. Critical findings** — none.

**3. Important findings**

- `lua/parley/cliproxy.lua:2070-2073` and `:2095-2096` (with `cliproxy_release.lua:180-183`) — **2nd finding in family `message-provenance`.** BR-4 fixed one instance; the rule it belongs to is: *every claim in an outcome message derives from an observation this call made; where the observation is unavailable, the message says so and names what to check.* Two sites still violate it:
  1. `port_identity` returns `{ ours = false }` when `ps` raises (this sandbox), when `lsof` is absent (default on many Linux installs: `pids_on_port` returns `{}` → `running_identity` returns nil → `ours = false`), or when `ps` is unreadable. `plan_update` then tells the operator the proxy "was not started by parley … stop it (e.g. `brew services stop cliproxyapi`)" as a fact, when parley launched it and simply could not confirm that. `ours` is a boolean carrying three states (ARCH-ORDER).
  2. After `restart_managed` calls `on_ready`, `update` reports ok "— restarting the proxy" without re-probing the version. `restart_managed` ignores `wait_port_released`'s boolean (`cliproxy.lua:469`) and proceeds to `ensure_running` after 2 s, which *reuses* a still-healthy dying proxy — the code's own comment at `:439-446` says the real binary shuts down gracefully, and the Python fake exits instantly, so the shipped test observes only the fast-exit interleaving. The Done-when says the serving proxy must be the new binary after `update`.
  Fix the rule, not the sites: make identity tri-state (`ours: true | false | nil` plus an `identity_err` such as "ps unreadable" / "lsof unavailable"), let `plan_update` word the unknown case as "could not tell whether parley started it (…); `:ParleyProxy restart` replaces it if it is parley's", and after `on_ready` feed one `version_probe` result into a pure `restart_outcome(target, probed)` that yields ok/warn text ("now serving 7.2.158" vs "the proxy still reports 7.1.71 — the old process has not exited; run `:ParleyProxy restart`"). Unit-test both in `cliproxy_release_spec.lua`.

**4. Minor findings**
- `tests/fixtures/fake_cliproxy` has no slow-shutdown seam (no SIGTERM handler, no exit delay), so the "old proxy slow to exit" row of the plan's ARCH-ORDER table cannot be reproduced; add e.g. `PARLEY_FAKE_EXIT_DELAY_MS` and a case that asserts the post-restart probe (ARCH-ORDER: a test that can only observe one interleaving).
- `cliproxy.lua:800-811` `pids_on_port` calls `vim.system` unguarded; `ps_output` and `port_identity` degrade on EPERM but `stop()` → `restart_managed` still raise, and `:ParleyProxy restart` now routes through it. Pre-existing; the pcall belongs in the IO wrapper, not its callers.
- The plan's Core-concepts tables do not list `tests/helpers/await.lua` (`settle`, `await`), the one new entity round 1 added; the arch sweep passed because it only inventories `lua/`.
- The Log's "26/0/0, none pending" predates the round-1 fix commit; the four `ps`-gated cases (now including BR-6's) have no recorded unsandboxed run at head.

**5. Test coverage notes**
- Verified by execution: target rule with request-log proofs, atomic install, checksum refusal, unknown record, refusals before network, env-seam gating, warn severity at the command layer, no-version port holder, first-run auto_download both ways, `await` consolidation (lifecycle and login specs green on the shared helper).
- Verified by reading only (pending here): restart-ours, second-update guard, deadline release, restart-failed. The BR-6 case pins the path: a stub `restart_managed` that calls `on_error` must produce `ok=false` with the "; the restart failed — …" suffix and release the guard; a broken path would either time out the 25 s await or fail `is_false`.
- Not covered: post-restart version confirmation (finding above); identity-unknown wording (finding above); `lsof`-absent degradation (only the empty-rows unit case).
- Live conformance for the redirect and the real binary's header remains M2 Task 13, as planned; the conformance spec at head has no `X-Cpa` case yet.

**6. Architectural notes**
- ARCH-DRY: pass — `NO_BINARY`, one `await`, one target rule, one `ps` grammar. `spawn_fake`/`reap` remain spec-local, deferred to #220 with the reason recorded.
- ARCH-PURE: pass — `update` is orchestration over `plan_update`; the identity and restart-outcome words should also be pure (see the Important finding) rather than assembled in `update`.
- ARCH-PURPOSE: flag — BR-4's family was fixed at the instance; the enumeration ("where does a message assert what the call did not observe") was not written, and two siblings remain. That is exactly the class-vs-instance pattern `workshop/lessons.md` and the memory note describe.
- ARCH-MOCK: pass — stateful release fake behind the production URL seam with a request log; live checks scheduled for M2.
- ARCH-CONSTRAINTS: pass — the synchronous fetch is operator-accepted and bounded; identity read is off the dispatch path; the 20 s deadline sits above the ~13 s restart budget.
- ARCH-SECURE: pass — env seam gated on the harness signal; versions parsed before entering any URL; the probe sends no credential; `delete(stage, "rf")` is a constructed leaf.
- ARCH-ORDER: flag — `running.ours` is a boolean carrying an unknown state, and the slow-exit interleaving has no seam; both are named in the Important finding.
- For M2: `status` should reuse the same tri-state identity and the post-restart probe rather than a second comparison; `binary_source` still says `"PATH"` for the managed dir (`cliproxy.lua:876`, Task 12).

**7. Plan revision recommendations**
- Add a `## Revisions` entry for this round: identity becomes tri-state and `update` re-probes after restart (Trust boundaries: "ps/lsof unreadable → unknown, never restart, say so"; ARCH-ORDER rows "listener identity unknown" and "old proxy still serving after restart" with their messages).
- Add `settle` / `await` (`tests/helpers/await.lua`, new) to the Integration points table.
- Record `PARLEY_FAKE_EXIT_DELAY_MS` (or whatever the slow-shutdown seam is named) under `tests/fixtures/fake_cliproxy` in the table and in Process ownership.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      README.md:221, atlas intro, config.lua comment and both "no cliproxy binary found" errors (one NO_BINARY text) now name :ParleyProxy update first; swept as a class.
  - id: BR-2
    disposition: addressed
    note: |
      releases_url() reads the env var only when $PARLEY_TEST_MODE is "1"; the harness case fails without the gate; plan Trust boundaries and atlas updated.
  - id: BR-3
    disposition: addressed
    note: |
      plan_update sets warn on the manual path, update forwards it, init.lua notifies at WARN; pinned by unit, integration and command-spec cases.
  - id: BR-4
    disposition: addressed
    note: |
      A port holder with no X-Cpa-Version gets a message that says only that; unit and integration cases assert no "brew". The family's rule is still unswept — see the new finding.
  - id: BR-5
    disposition: addressed
    note: |
      await/settle live once in tests/helpers/await.lua and all three specs bind to it; the spawn_fake/reap ownership registry is deferred to #220 with the reason recorded in the plan.
  - id: BR-6
    disposition: addressed
    note: |
      "reports a restart that fails, and releases the guard" exists and pins the on_error path; it is ps-gated and went pending in this shell, so verified by reading, not execution.
  - id: BR-7
    disposition: addressed
    note: |
      54 of 68 steps ticked; the 14 unticked rows are all in M2 Tasks 11–13.
findings:
  - id: new
    severity: Important
    family: message-provenance
    title: |
      update still asserts what it did not observe: an unreadable identity is worded as "not started by parley", and a restart's success is reported without re-probing the version
    detail: |
      2nd finding in this family. Rule: every claim in an outcome message derives from an observation the call made; otherwise say "could not tell" and name what to check. Sites: port_identity collapses ps-EPERM / no-lsof into ours=false and plan_update words it as fact with the brew hint (cliproxy.lua:2072, cliproxy_release.lua:180); after restart_managed's on_ready, update reports ok "restarting the proxy" while restart_managed ignores wait_port_released's result and ensure_running reuses a still-dying old proxy (cliproxy.lua:469, :2095) — the Done-when says the serving proxy must be the new binary. Fix the class: tri-state identity with a reason, and a pure restart_outcome fed by a post-restart version_probe.
  - id: new
    severity: Minor
    family: interleaving-seam
    title: |
      The "old proxy slow to exit" ordering has no seam: fake_cliproxy exits instantly on SIGTERM, so only the fast-exit interleaving is ever observed
    detail: |
      Add an exit-delay seam to tests/fixtures/fake_cliproxy and a case that drives update through a slow shutdown and asserts what version_probe reports afterwards (ARCH-ORDER: a green run of a one-interleaving test is a sample of size one).
  - id: new
    severity: Minor
    family: degrade-at-the-io-seam
    title: |
      pids_on_port calls vim.system unguarded, so a refused lsof raises out of stop() and restart_managed while ps_output and port_identity degrade
    detail: |
      cliproxy.lua:800-811; pre-existing, but :ParleyProxy restart and update's managed restart now route through it. Put the pcall in the wrapper, as ps_output does, rather than in each caller.
  - id: new
    severity: Minor
    family: plan-checkbox-tracking
    title: |
      The Core-concepts tables omit the one entity round 1 added, tests/helpers/await.lua (settle, await)
    detail: |
      The arch sweep inventories lua/ only, so it did not catch the gap; add the row so the table stays the inventory the review reads against.
```

---

## Re-review — 2026-09-12T13:14:05-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 237 — ParleyProxy update fetches the latest release unless pinned; status shows the version |
| repo | parley.nvim |
| issue file | workshop/issues/000237-proxy-update-latest.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 27bac4f4ba965e52f1026b0f1809036bbdfd41e4..8c16e763532ff24282212affcdb51c2e38880f82 |
| command | sdlc milestone-close --issue 237 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-12T13:14:05-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

**Summary.** M1 delivers what the Spec and the plan's Tasks 1–9 (+10) promise, and round 2's fixes are real: identity is tri-state with a reason, `plan_update` never restarts what it could not identify, `restart_managed` reports a cliproxyapi that outlives its 2 s wait instead of reusing it, and `update` confirms a restart with one probe through pure `restart_outcome`. I verified by execution where this shell allows: lint 0/0; release unit 50/0; auth 78/0; download 6/0; command 15/0; login 13/0; lifecycle 53/0; recovery 5/0; arch sweep 21/0; update spec 31/0 with **6 pending** (`ps` is refused here, also from inside nvim). I drove `restart_managed` directly against a fake serving 4 s after SIGTERM: it answered through `on_error` at 2.2 s and the port still reported the old version, never reused. Reverting the `restart = "unknown"` branch turned the "could not tell" integration case and one unit case red, so the identity half is pinned by tests that fail without it. What keeps this from SHIP: BR-10's guard has no pinning test, and the six cases that pin BR-6, BR-8's restart half and BR-9 cannot execute anywhere `ps` is refused, which so far includes two of three review shells, although the seam to make them run everywhere already exists. Confidence is medium for that reason only.

**Operator notice.** The sandbox refused `mktemp`, so a scratch copy I meant to revert-test in was never created and two `sed` edits landed in the real worktree (`lua/parley/cliproxy.lua`, `lua/parley/cliproxy_release.lua`). I reversed both in place with the inverse edits, not `git checkout`, and `git diff -- lua/ tests/ atlas/ README.md workshop/` is empty except your pre-existing deletion of `workshop/parley/2026-09-10.11-10-24.522.md`. No untracked file was touched. Lesson 1 in `workshop/lessons.md` (snapshot WIP before dispatching a review) applies to this round too.

**1. Strengths**
- `lua/parley/cliproxy_release.lua:104-133` and `:163-198`: identity is `{ours}` or `nil, why`, and `plan_update` maps `ours == nil` to `restart = "unknown"` with `warn`. The 2^N flag constellation BR-8 named is now a three-valued enum with a reason (ARCH-ORDER).
- `lua/parley/cliproxy.lua:475-486`: `restart_managed` reads `wait_port_released`'s state through the shared `is_cliproxy_state` and errors instead of reusing; I observed this on the real tree with the exit-delay seam, which propagates through the managed spawn as designed.
- `lua/parley/cliproxy.lua:2143-2156`: after `on_ready`, one `version_probe` feeds `restart_outcome`; the deadline still owns the never-answers path and `finish` drops the second answer.
- `tests/integration/cliproxy_update_spec.lua:372-390`: the "could not tell" case runs in every environment via `_set_process_tools`, asserts the exact message, and goes red without the fix (verified).
- The Revisions entry for round 2 enumerates every outcome message beside its observation, and `workshop/lessons.md` records the rule. That is the class fix the family asked for.

**2. Critical findings** — none.

**3. Important findings**
- `tests/integration/cliproxy_update_spec.lua:214-231` (`PS_OK` / `needs_ps`) — six cases are gated on a real `ps`: restarts-ours, not-ours, second-update guard, deadline release, restart-failed (BR-6), slow-exit (BR-9). They are the pins for three claimed fixes and went pending in this shell and in round 2's. `_set_process_tools` already accepts a `ps` path (`cliproxy.lua:818`), and `lsof` works here, so a `tests/fixtures/fake_ps` that prints `ps ax -o pid,lstart,command` rows from an env var (the spec builds the row from `cliproxy.spawned_pids()` and the rendered config path, e.g. `PARLEY_FAKE_PS_TABLE="<pid> Mon Jan  1 00:00:00 2026 /x/cli-proxy-api -config <path>"`) would let all six run everywhere and drop `needs_ps`. Round 2 added the seam for the one negative case; the enumeration of the gated cases was not swept (ARCH-PURPOSE instance vs class; ARCH-MOCK: `ps` is an external binary read without a fake).

**4. Minor findings**
- BR-10 (disposed `not-addressed` below): `pids_on_port` is now guarded (`cliproxy.lua:826-835`) but nothing pins it. Recipe that works in any environment (verified): an executable file whose shebang names a missing interpreter passes `vim.fn.executable()` yet makes `vim.system` raise `ENOENT`; point `_set_process_tools({ lsof = <that file> })` at it and assert `stop()` returns and `port_identity` yields "lsof unreadable".
- `running_identity`'s reason "no process found listening on the port" is reached only after the port answered a probe; "lsof lists no process on the port" says what was observed (a root-owned holder is invisible to a user's `lsof`).

**5. Test coverage notes**
- Executed green here: target rule with request-log proofs, atomic install by inode, checksum refusal, refusals before network, env-seam gating, no-version holder, could-not-tell wording, first-run auto_download both ways, command-layer severities, `await`/`settle` consumers.
- Pending here, verified by reading plus my direct drive of `restart_managed`: the six `ps`-gated cases above.
- Unit coverage of `restart_outcome` covers all five branches; `plan_update` covers `unknown` with and without a version.

**6. Architectural notes**
- ARCH-DRY: pass. One `ps` grammar, one `is_cliproxy_state`, one `NO_BINARY`, one `await`. `spawn_fake`/`reap` deferral to #220 stands.
- ARCH-PURE: pass. `port_identity` and `update` are thin; every decision and every message is pure and unit-tested without IO.
- ARCH-PURPOSE: flag, the Important finding: the seam fixed one case, its siblings stay gated.
- ARCH-MOCK: pass for GitHub and the proxy; flag for `ps` (no fake). Live conformance for the redirect and the real header remains M2 Task 13 as planned.
- ARCH-CONSTRAINTS: pass. `restart_managed`'s worst case (~15 s with the confirming probe) stays under the 20 s deadline; identity read is update-only.
- ARCH-SECURE: pass. Env seam gated on the harness signal; versions parsed before any URL; probe sends no credential.
- ARCH-ORDER: pass on the code; flag on the oracle, since the slow-exit and restart-failed interleavings are unobservable wherever `ps` is refused.

**7. Plan revision recommendations**
- Add to Process ownership / Test surface: the `ps`-gated cases and how they run in a sandbox (a `fake_ps` fixture row under Integration points once added).
- Record the BR-10 pinning recipe under Task 7 or the round-3 Revisions.

```findings
dispose:
  - id: BR-8
    disposition: addressed
    note: |
      Tri-state identity with reason, restart="unknown" never restarts, restart_managed errors on a still-answering proxy, restart_outcome fed by a post-restart probe; reverting the unknown branch turns two tests red, and a direct drive against a 4 s-exit fake showed on_error at 2.2 s with the old version still on the port.
  - id: BR-9
    disposition: addressed
    note: |
      PARLEY_FAKE_EXIT_DELAY_MS in fake_cliproxy, propagated through the managed spawn (observed); the spec case exists but is ps-gated and pending here.
  - id: BR-10
    disposition: not-addressed
    note: |
      The pcall is in pids_on_port, but no test pins it; a script with a missing-interpreter shebang passes executable() and makes vim.system raise, so the case is writable anywhere.
  - id: BR-11
    disposition: addressed
    note: |
      settle and await rows are in the Integration points table.
findings:
  - id: new
    severity: Important
    family: env-gated-coverage
    title: |
      Six update cases, the pins for BR-6, BR-8 and BR-9, only run where a real ps is permitted, although _set_process_tools already accepts a fake one
    detail: |
      cliproxy_update_spec.lua needs_ps gates restarts-ours, not-ours, second-update, deadline, restart-failed and slow-exit; they went pending in two of three review shells. A tests/fixtures/fake_ps that prints rows from an env var built with spawned_pids() and the rendered config path would let them run everywhere (ARCH-PURPOSE: the seam fixed one case, not the class; ARCH-MOCK: ps has no fake).
```
