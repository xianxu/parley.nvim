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

## Open findings

- **BR-1** [Important] `readme-surface-drift` README does not describe the changed :ParleyProxy update semantics or the download_version pin
- **BR-2** [Minor] `test-seam-in-production` $PARLEY_CLIPROXY_RELEASES_URL redirects production downloads and is absent from the trust table
- **BR-3** [Minor] `outcome-severity` A manual-restart outcome is reported as ok=true and shown at INFO
- **BR-4** [Minor] `message-provenance` A non-cliproxy port holder gets the "brew services stop cliproxyapi" hint
- **BR-5** [Minor] `test-helper-duplication` await, spawn_fake and reap are copy-pasted across three cliproxy specs
- **BR-6** [Minor] `error-path-coverage` update's "the restart failed" transition has no test
- **BR-7** [Minor] `plan-checkbox-tracking` No plan step checkboxes are ticked although Tasks 1–8 are logged as done
