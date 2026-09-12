---
gate: boundary-review
issue: 237
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-12T12:21:01-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: README does not describe the changed :ParleyProxy update semantics or the download_version pin
          detail: README.md:221 lists `update` bare and still says a fresh install should expect `brew install`; the diff makes update install the latest release or the download_version pin and restart parley's proxy, and auto_download is on by default. One sentence fixes it.
          family: readme-surface-drift
          round: 1
        - id: BR-2
          severity: Minor
          title: $PARLEY_CLIPROXY_RELEASES_URL redirects production downloads and is absent from the trust table
          detail: releases_url() in cliproxy.lua honours the env var outside tests; gate it on PARLEY_TEST_MODE or document it as a supported override in the plan's Trust boundaries and the atlas.
          family: test-seam-in-production
          round: 1
        - id: BR-3
          severity: Minor
          title: A manual-restart outcome is reported as ok=true and shown at INFO
          detail: plan_update's restart="manual" path means the proxy still serves the old version; init.lua notifies the message at INFO because update() returned ok=true.
          family: outcome-severity
          round: 1
        - id: BR-4
          severity: Minor
          title: A non-cliproxy port holder gets the "brew services stop cliproxyapi" hint
          detail: version_probe reports no_header (not down) for any HTTP server on the port, so plan_update words it as a foreign cliproxy; ensure_running already distinguishes that case.
          family: message-provenance
          round: 1
        - id: BR-5
          severity: Minor
          title: await, spawn_fake and reap are copy-pasted across three cliproxy specs
          detail: cliproxy_update_spec adds a third `await`; tests/helpers is the home (ARCH-DRY on the test side).
          family: test-helper-duplication
          round: 1
        - id: BR-6
          severity: Minor
          title: update's "the restart failed" transition has no test
          detail: Stub restart_managed to call its on_error and assert the message and released guard; the never-answers and second-update orderings are covered, this cell is not.
          family: error-path-coverage
          round: 1
        - id: BR-7
          severity: Minor
          title: No plan step checkboxes are ticked although Tasks 1–8 are logged as done
          detail: 0 of 68 `- [ ]` rows in the plan are ticked; tick the M1 steps at milestone close.
          family: plan-checkbox-tracking
          round: 1
      boundary: M1
      blocked: true
    - "n": 2
      timestamp: "2026-09-12T12:49:03-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: README.md:221, atlas intro, config.lua comment and both "no cliproxy binary found" errors (one NO_BINARY text) now name :ParleyProxy update first; swept as a class.
          round: 2
        - id: BR-2
          disposition: addressed
          note: releases_url() reads the env var only when $PARLEY_TEST_MODE is "1"; the harness case fails without the gate; plan Trust boundaries and atlas updated.
          round: 2
        - id: BR-3
          disposition: addressed
          note: plan_update sets warn on the manual path, update forwards it, init.lua notifies at WARN; pinned by unit, integration and command-spec cases.
          round: 2
        - id: BR-4
          disposition: addressed
          note: A port holder with no X-Cpa-Version gets a message that says only that; unit and integration cases assert no "brew". The family's rule is still unswept — see the new finding.
          round: 2
        - id: BR-5
          disposition: addressed
          note: 'await/settle live once in tests/helpers/await.lua and all three specs bind to it; the spawn_fake/reap ownership registry is deferred to #220 with the reason recorded in the plan.'
          round: 2
        - id: BR-6
          disposition: addressed
          note: '"reports a restart that fails, and releases the guard" exists and pins the on_error path; it is ps-gated and went pending in this shell, so verified by reading, not execution.'
          round: 2
        - id: BR-7
          disposition: addressed
          note: 54 of 68 steps ticked; the 14 unticked rows are all in M2 Tasks 11–13.
          round: 2
      findings:
        - id: BR-8
          severity: Important
          title: 'update still asserts what it did not observe: an unreadable identity is worded as "not started by parley", and a restart''s success is reported without re-probing the version'
          detail: '2nd finding in this family. Rule: every claim in an outcome message derives from an observation the call made; otherwise say "could not tell" and name what to check. Sites: port_identity collapses ps-EPERM / no-lsof into ours=false and plan_update words it as fact with the brew hint (cliproxy.lua:2072, cliproxy_release.lua:180); after restart_managed''s on_ready, update reports ok "restarting the proxy" while restart_managed ignores wait_port_released''s result and ensure_running reuses a still-dying old proxy (cliproxy.lua:469, :2095) — the Done-when says the serving proxy must be the new binary. Fix the class: tri-state identity with a reason, and a pure restart_outcome fed by a post-restart version_probe.'
          family: message-provenance
          round: 2
        - id: BR-9
          severity: Minor
          title: 'The "old proxy slow to exit" ordering has no seam: fake_cliproxy exits instantly on SIGTERM, so only the fast-exit interleaving is ever observed'
          detail: 'Add an exit-delay seam to tests/fixtures/fake_cliproxy and a case that drives update through a slow shutdown and asserts what version_probe reports afterwards (ARCH-ORDER: a green run of a one-interleaving test is a sample of size one).'
          family: interleaving-seam
          round: 2
        - id: BR-10
          severity: Minor
          title: pids_on_port calls vim.system unguarded, so a refused lsof raises out of stop() and restart_managed while ps_output and port_identity degrade
          detail: cliproxy.lua:800-811; pre-existing, but :ParleyProxy restart and update's managed restart now route through it. Put the pcall in the wrapper, as ps_output does, rather than in each caller.
          family: degrade-at-the-io-seam
          round: 2
        - id: BR-11
          severity: Minor
          title: The Core-concepts tables omit the one entity round 1 added, tests/helpers/await.lua (settle, await)
          detail: The arch sweep inventories lua/ only, so it did not catch the gap; add the row so the table stays the inventory the review reads against.
          family: plan-checkbox-tracking
          round: 2
      boundary: M1
      blocked: true
---

# Gate ledger — parley.nvim#237 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-12T12:21:01-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `readme-surface-drift` README does not describe the changed :ParleyProxy update semantics or the download_version pin
  README.md:221 lists `update` bare and still says a fresh install should expect `brew install`; the diff makes update install the latest release or the download_version pin and restart parley's proxy, and auto_download is on by default. One sentence fixes it.
- **BR-2** [Minor] `test-seam-in-production` $PARLEY_CLIPROXY_RELEASES_URL redirects production downloads and is absent from the trust table
  releases_url() in cliproxy.lua honours the env var outside tests; gate it on PARLEY_TEST_MODE or document it as a supported override in the plan's Trust boundaries and the atlas.
- **BR-3** [Minor] `outcome-severity` A manual-restart outcome is reported as ok=true and shown at INFO
  plan_update's restart="manual" path means the proxy still serves the old version; init.lua notifies the message at INFO because update() returned ok=true.
- **BR-4** [Minor] `message-provenance` A non-cliproxy port holder gets the "brew services stop cliproxyapi" hint
  version_probe reports no_header (not down) for any HTTP server on the port, so plan_update words it as a foreign cliproxy; ensure_running already distinguishes that case.
- **BR-5** [Minor] `test-helper-duplication` await, spawn_fake and reap are copy-pasted across three cliproxy specs
  cliproxy_update_spec adds a third `await`; tests/helpers is the home (ARCH-DRY on the test side).
- **BR-6** [Minor] `error-path-coverage` update's "the restart failed" transition has no test
  Stub restart_managed to call its on_error and assert the message and released guard; the never-answers and second-update orderings are covered, this cell is not.
- **BR-7** [Minor] `plan-checkbox-tracking` No plan step checkboxes are ticked although Tasks 1–8 are logged as done
  0 of 68 `- [ ]` rows in the plan are ticked; tick the M1 steps at milestone close.

## Round 2 — 2026-09-12T12:49:03-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — README.md:221, atlas intro, config.lua comment and both "no cliproxy binary found" errors (one NO_BINARY text) now name :ParleyProxy update first; swept as a class.
- BR-2 — addressed — releases_url() reads the env var only when $PARLEY_TEST_MODE is "1"; the harness case fails without the gate; plan Trust boundaries and atlas updated.
- BR-3 — addressed — plan_update sets warn on the manual path, update forwards it, init.lua notifies at WARN; pinned by unit, integration and command-spec cases.
- BR-4 — addressed — A port holder with no X-Cpa-Version gets a message that says only that; unit and integration cases assert no "brew". The family's rule is still unswept — see the new finding.
- BR-5 — addressed — await/settle live once in tests/helpers/await.lua and all three specs bind to it; the spawn_fake/reap ownership registry is deferred to #220 with the reason recorded in the plan.
- BR-6 — addressed — "reports a restart that fails, and releases the guard" exists and pins the on_error path; it is ps-gated and went pending in this shell, so verified by reading, not execution.
- BR-7 — addressed — 54 of 68 steps ticked; the 14 unticked rows are all in M2 Tasks 11–13.

### Raised

- **BR-8** [Important] `message-provenance` update still asserts what it did not observe: an unreadable identity is worded as "not started by parley", and a restart's success is reported without re-probing the version
  2nd finding in this family. Rule: every claim in an outcome message derives from an observation the call made; otherwise say "could not tell" and name what to check. Sites: port_identity collapses ps-EPERM / no-lsof into ours=false and plan_update words it as fact with the brew hint (cliproxy.lua:2072, cliproxy_release.lua:180); after restart_managed's on_ready, update reports ok "restarting the proxy" while restart_managed ignores wait_port_released's result and ensure_running reuses a still-dying old proxy (cliproxy.lua:469, :2095) — the Done-when says the serving proxy must be the new binary. Fix the class: tri-state identity with a reason, and a pure restart_outcome fed by a post-restart version_probe.
- **BR-9** [Minor] `interleaving-seam` The "old proxy slow to exit" ordering has no seam: fake_cliproxy exits instantly on SIGTERM, so only the fast-exit interleaving is ever observed
  Add an exit-delay seam to tests/fixtures/fake_cliproxy and a case that drives update through a slow shutdown and asserts what version_probe reports afterwards (ARCH-ORDER: a green run of a one-interleaving test is a sample of size one).
- **BR-10** [Minor] `degrade-at-the-io-seam` pids_on_port calls vim.system unguarded, so a refused lsof raises out of stop() and restart_managed while ps_output and port_identity degrade
  cliproxy.lua:800-811; pre-existing, but :ParleyProxy restart and update's managed restart now route through it. Put the pcall in the wrapper, as ps_output does, rather than in each caller.
- **BR-11** [Minor] `plan-checkbox-tracking` The Core-concepts tables omit the one entity round 1 added, tests/helpers/await.lua (settle, await)
  The arch sweep inventories lua/ only, so it did not catch the gap; add the row so the table stays the inventory the review reads against.

## Open findings

- **BR-8** [Important] `message-provenance` update still asserts what it did not observe: an unreadable identity is worded as "not started by parley", and a restart's success is reported without re-probing the version
- **BR-9** [Minor] `interleaving-seam` The "old proxy slow to exit" ordering has no seam: fake_cliproxy exits instantly on SIGTERM, so only the fast-exit interleaving is ever observed
- **BR-10** [Minor] `degrade-at-the-io-seam` pids_on_port calls vim.system unguarded, so a refused lsof raises out of stop() and restart_managed while ps_output and port_identity degrade
- **BR-11** [Minor] `plan-checkbox-tracking` The Core-concepts tables omit the one entity round 1 added, tests/helpers/await.lua (settle, await)
