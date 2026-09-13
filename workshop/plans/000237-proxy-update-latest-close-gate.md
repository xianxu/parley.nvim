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
    - "n": 3
      timestamp: "2026-09-12T13:14:05-07:00"
      agent: claude
      dispose:
        - id: BR-8
          disposition: addressed
          note: Tri-state identity with reason, restart="unknown" never restarts, restart_managed errors on a still-answering proxy, restart_outcome fed by a post-restart probe; reverting the unknown branch turns two tests red, and a direct drive against a 4 s-exit fake showed on_error at 2.2 s with the old version still on the port.
          round: 3
        - id: BR-9
          disposition: addressed
          note: PARLEY_FAKE_EXIT_DELAY_MS in fake_cliproxy, propagated through the managed spawn (observed); the spec case exists but is ps-gated and pending here.
          round: 3
        - id: BR-10
          disposition: not-addressed
          note: The pcall is in pids_on_port, but no test pins it; a script with a missing-interpreter shebang passes executable() and makes vim.system raise, so the case is writable anywhere.
          round: 3
        - id: BR-11
          disposition: addressed
          note: settle and await rows are in the Integration points table.
          round: 3
      findings:
        - id: BR-12
          severity: Important
          title: Six update cases, the pins for BR-6, BR-8 and BR-9, only run where a real ps is permitted, although _set_process_tools already accepts a fake one
          detail: 'cliproxy_update_spec.lua needs_ps gates restarts-ours, not-ours, second-update, deadline, restart-failed and slow-exit; they went pending in two of three review shells. A tests/fixtures/fake_ps that prints rows from an env var built with spawned_pids() and the rendered config path would let them run everywhere (ARCH-PURPOSE: the seam fixed one case, not the class; ARCH-MOCK: ps has no fake).'
          family: env-gated-coverage
          round: 3
      boundary: M1
      blocked: true
    - "n": 4
      timestamp: "2026-09-12T13:33:31-07:00"
      agent: claude
      dispose:
        - id: BR-10
          disposition: addressed
          note: pids_on_port's pcall is pinned by "says why, and does not raise, when lsof cannot run"; reverting the guard in a scratch copy turns exactly that case red (31/1), and it asserts stop() does not raise.
          round: 4
        - id: BR-12
          disposition: addressed
          note: needs_ps is gone; tests/fixtures/fake_ps behind _set_process_tools makes all six identity cases execute in this ps-refused shell (32/0, none pending), and dropping the fake's rows turns all six red (26/6), so they read it rather than pass vacuously.
          round: 4
      findings:
        - id: BR-13
          severity: Minor
          title: The atlas still says the identity cases report pending where ps is refused, which round 3 made false, and never names fake_ps
          detail: 'atlas/providers/cliproxy-managed.md:447-449. 2nd finding in this family; the rule is: sweep every doc sentence that restates a behaviour the commit changes, in the same commit, by grepping for the old behaviour''s key phrase. Replace the sentence with the fake_ps mechanism (PARLEY_FAKE_PS_ROWS via _set_process_tools) so the atlas Testing paragraph matches the spec.'
          family: readme-surface-drift
          round: 4
      boundary: M1
      blocked: false
    - "n": 5
      timestamp: "2026-09-12T16:09:00-07:00"
      agent: claude
      findings:
        - id: BR-14
          severity: Critical
          title: 'Unauthenticated version_probe trips 7.2.x''s management lockout: 5 failed attempts ban 127.0.0.1 from keyed management reads for 30 min'
          detail: 'Measured on the installed 7.2.159: five unauthenticated GET /v0/management/latest-version answer 401, the sixth onward 403 "IP banned due to too many failed attempts. Try again in 30m0s", and a request with the correct management key is then 403 too. Each :ParleyProxy status is one failed attempt, each update two (cliproxy.lua:949, :2150, :2181), so auth_files/recovery/login read "unknown" after a few uses; the operator''s live proxy was already banned. Send M.management_key() as auth_files does (cliproxy.lua:368), model the counter in fake_cliproxy, pin it in conformance, carry the 403 body in auth_files'' message, fix atlas/decision 3.'
          family: stateless-fake-for-stateful-dependency
          round: 5
        - id: BR-15
          severity: Important
          title: Conformance discovers the binary after _set_data_dir(tempname), so parley's managed download is never seen and every M2 live case is pending on a brew-less machine
          detail: 'cliproxy_conformance_spec.lua:22 overrides the data dir before :38 discovers, so only a PATH binary counts; the atlas claim "parley''s download, or one on PATH" is false. 2nd finding in env-gated-coverage: the rule is that a gated check must be satisfiable by the environment the project itself produces — resolve BINARY from the real data root first, and report the gate as pending rather than a print.'
          family: env-gated-coverage
          round: 5
        - id: BR-16
          severity: Minor
          title: fake_cliproxy's new 404 rule has no spec that posts the anthropic route through it; the unit pin is the only protection
          family: fake-rule-without-driver
          round: 5
        - id: BR-17
          severity: Minor
          title: The status join is reproducible only with the latest leg slow; health/version legs have no delay seam in fake_cliproxy
          detail: '2nd finding in interleaving-seam. Rule: every async join gets a per-leg delay seam so each leg can be made to land last. Counter is symmetric, so coverage note only.'
          family: interleaving-seam
          round: 5
        - id: BR-18
          severity: Minor
          title: status re-walks discover_binary's precedence to label binary_source; return (path, source) from discover_binary instead
          family: binary-provenance-single-source
          round: 5
        - id: BR-19
          severity: Minor
          title: The claude /v1/messages route change is recorded in the Log and plan Revisions but not in the issue Spec or its Revisions
          family: spec-carries-discovered-scope
          round: 5
      boundary: M2
      blocked: true
    - "n": 6
      timestamp: "2026-09-12T16:28:46-07:00"
      agent: claude
      boundary: M2
      blocked: true
      protocol_error: no valid findings block
    - "n": 7
      timestamp: "2026-09-12T17:24:57-07:00"
      agent: claude
      dispose:
        - id: BR-14
          disposition: addressed
          note: 'Keyed probe pinned: reverting the key turns the lockout case red (39/1); re-measured on 7.2.159 today, the fake''s counter and ban body match the real binary.'
          round: 7
        - id: BR-15
          disposition: addressed
          note: Every real-binary case now reports the reason it is pending, and PARLEY_LIVE_GITHUB=1 installs the latest release through parley's own download; the milestone close on a brew-less machine must set that flag.
          round: 7
        - id: BR-16
          disposition: not-addressed
          note: 'The recovery case posts to /v1/chat/completions (fake''s POST log: 7 of 7); dispatcher.query never calls format_payload, so _parley_route is never "anthropic" and the case stays green with the route fix reverted.'
          round: 7
        - id: BR-17
          disposition: addressed
          note: PARLEY_FAKE_GET_DELAY_MS lands the proxy legs last; the case asserts a single callback with all three reads filled.
          round: 7
        - id: BR-18
          disposition: addressed
          note: discover_binary returns (path, source); status reads it; lifecycle 53/0 and download 6/0 with the extra return value.
          round: 7
        - id: BR-19
          disposition: addressed
          note: The issue's Revisions carry both the route change and the keyed probe.
          round: 7
      findings:
        - id: BR-20
          severity: Minor
          title: The conformance lockout case pins the 403 code but not the error body field auth_files now parses
          detail: cliproxy.lua:388-396 reads payload.error from a non-200 management body; cliproxy_conformance_spec.lua:386-407 asserts only "403". Pin the field the way REQUIRED_FIELDS pins auth-files, so drift in the ban body is caught live rather than by an operator reading "HTTP 403".
          family: conformance-pins-parsed-fields
          round: 7
        - id: BR-21
          severity: Minor
          title: 'Core-concepts rows lag the diff: the fake_cliproxy row omits the lockout counter, the POST 404 rule and the GET delay seam, and auth_files has no modified row'
          detail: '3rd finding in this family. Rule: every entity the diff modifies gets its table row amended in the same commit; the arch sweep fires only on definition-line changes, so a contract change inside a function (auth_files'' message) or inside a fixture never trips it. Sweep the fake''s row (plan line 287) and add the auth_files row.'
          family: plan-checkbox-tracking
          round: 7
      boundary: M2
      blocked: false
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

## Round 3 — 2026-09-12T13:14:05-07:00 (claude) — BLOCKED

### Disposed

- BR-8 — addressed — Tri-state identity with reason, restart="unknown" never restarts, restart_managed errors on a still-answering proxy, restart_outcome fed by a post-restart probe; reverting the unknown branch turns two tests red, and a direct drive against a 4 s-exit fake showed on_error at 2.2 s with the old version still on the port.
- BR-9 — addressed — PARLEY_FAKE_EXIT_DELAY_MS in fake_cliproxy, propagated through the managed spawn (observed); the spec case exists but is ps-gated and pending here.
- BR-10 — not-addressed — The pcall is in pids_on_port, but no test pins it; a script with a missing-interpreter shebang passes executable() and makes vim.system raise, so the case is writable anywhere.
- BR-11 — addressed — settle and await rows are in the Integration points table.

### Raised

- **BR-12** [Important] `env-gated-coverage` Six update cases, the pins for BR-6, BR-8 and BR-9, only run where a real ps is permitted, although _set_process_tools already accepts a fake one
  cliproxy_update_spec.lua needs_ps gates restarts-ours, not-ours, second-update, deadline, restart-failed and slow-exit; they went pending in two of three review shells. A tests/fixtures/fake_ps that prints rows from an env var built with spawned_pids() and the rendered config path would let them run everywhere (ARCH-PURPOSE: the seam fixed one case, not the class; ARCH-MOCK: ps has no fake).

## Round 4 — 2026-09-12T13:33:31-07:00 (claude) — passed

### Disposed

- BR-10 — addressed — pids_on_port's pcall is pinned by "says why, and does not raise, when lsof cannot run"; reverting the guard in a scratch copy turns exactly that case red (31/1), and it asserts stop() does not raise.
- BR-12 — addressed — needs_ps is gone; tests/fixtures/fake_ps behind _set_process_tools makes all six identity cases execute in this ps-refused shell (32/0, none pending), and dropping the fake's rows turns all six red (26/6), so they read it rather than pass vacuously.

### Raised

- **BR-13** [Minor] `readme-surface-drift` The atlas still says the identity cases report pending where ps is refused, which round 3 made false, and never names fake_ps
  atlas/providers/cliproxy-managed.md:447-449. 2nd finding in this family; the rule is: sweep every doc sentence that restates a behaviour the commit changes, in the same commit, by grepping for the old behaviour's key phrase. Replace the sentence with the fake_ps mechanism (PARLEY_FAKE_PS_ROWS via _set_process_tools) so the atlas Testing paragraph matches the spec.

## Round 5 — 2026-09-12T16:09:00-07:00 (claude) — BLOCKED

### Raised

- **BR-14** [Critical] `stateless-fake-for-stateful-dependency` Unauthenticated version_probe trips 7.2.x's management lockout: 5 failed attempts ban 127.0.0.1 from keyed management reads for 30 min
  Measured on the installed 7.2.159: five unauthenticated GET /v0/management/latest-version answer 401, the sixth onward 403 "IP banned due to too many failed attempts. Try again in 30m0s", and a request with the correct management key is then 403 too. Each :ParleyProxy status is one failed attempt, each update two (cliproxy.lua:949, :2150, :2181), so auth_files/recovery/login read "unknown" after a few uses; the operator's live proxy was already banned. Send M.management_key() as auth_files does (cliproxy.lua:368), model the counter in fake_cliproxy, pin it in conformance, carry the 403 body in auth_files' message, fix atlas/decision 3.
- **BR-15** [Important] `env-gated-coverage` Conformance discovers the binary after _set_data_dir(tempname), so parley's managed download is never seen and every M2 live case is pending on a brew-less machine
  cliproxy_conformance_spec.lua:22 overrides the data dir before :38 discovers, so only a PATH binary counts; the atlas claim "parley's download, or one on PATH" is false. 2nd finding in env-gated-coverage: the rule is that a gated check must be satisfiable by the environment the project itself produces — resolve BINARY from the real data root first, and report the gate as pending rather than a print.
- **BR-16** [Minor] `fake-rule-without-driver` fake_cliproxy's new 404 rule has no spec that posts the anthropic route through it; the unit pin is the only protection
- **BR-17** [Minor] `interleaving-seam` The status join is reproducible only with the latest leg slow; health/version legs have no delay seam in fake_cliproxy
  2nd finding in interleaving-seam. Rule: every async join gets a per-leg delay seam so each leg can be made to land last. Counter is symmetric, so coverage note only.
- **BR-18** [Minor] `binary-provenance-single-source` status re-walks discover_binary's precedence to label binary_source; return (path, source) from discover_binary instead
- **BR-19** [Minor] `spec-carries-discovered-scope` The claude /v1/messages route change is recorded in the Log and plan Revisions but not in the issue Spec or its Revisions

## Round 6 — 2026-09-12T16:28:46-07:00 (claude) — BLOCKED

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 7 — 2026-09-12T17:24:57-07:00 (claude) — passed

### Disposed

- BR-14 — addressed — Keyed probe pinned: reverting the key turns the lockout case red (39/1); re-measured on 7.2.159 today, the fake's counter and ban body match the real binary.
- BR-15 — addressed — Every real-binary case now reports the reason it is pending, and PARLEY_LIVE_GITHUB=1 installs the latest release through parley's own download; the milestone close on a brew-less machine must set that flag.
- BR-16 — not-addressed — The recovery case posts to /v1/chat/completions (fake's POST log: 7 of 7); dispatcher.query never calls format_payload, so _parley_route is never "anthropic" and the case stays green with the route fix reverted.
- BR-17 — addressed — PARLEY_FAKE_GET_DELAY_MS lands the proxy legs last; the case asserts a single callback with all three reads filled.
- BR-18 — addressed — discover_binary returns (path, source); status reads it; lifecycle 53/0 and download 6/0 with the extra return value.
- BR-19 — addressed — The issue's Revisions carry both the route change and the keyed probe.

### Raised

- **BR-20** [Minor] `conformance-pins-parsed-fields` The conformance lockout case pins the 403 code but not the error body field auth_files now parses
  cliproxy.lua:388-396 reads payload.error from a non-200 management body; cliproxy_conformance_spec.lua:386-407 asserts only "403". Pin the field the way REQUIRED_FIELDS pins auth-files, so drift in the ban body is caught live rather than by an operator reading "HTTP 403".
- **BR-21** [Minor] `plan-checkbox-tracking` Core-concepts rows lag the diff: the fake_cliproxy row omits the lockout counter, the POST 404 rule and the GET delay seam, and auth_files has no modified row
  3rd finding in this family. Rule: every entity the diff modifies gets its table row amended in the same commit; the arch sweep fires only on definition-line changes, so a contract change inside a function (auth_files' message) or inside a fixture never trips it. Sweep the fake's row (plan line 287) and add the auth_files row.

## Open findings

- **BR-13** [Minor] `readme-surface-drift` The atlas still says the identity cases report pending where ps is refused, which round 3 made false, and never names fake_ps
- **BR-16** [Minor] `fake-rule-without-driver` fake_cliproxy's new 404 rule has no spec that posts the anthropic route through it; the unit pin is the only protection
- **BR-20** [Minor] `conformance-pins-parsed-fields` The conformance lockout case pins the 403 code but not the error body field auth_files now parses
- **BR-21** [Minor] `plan-checkbox-tracking` Core-concepts rows lag the diff: the fake_cliproxy row omits the lockout counter, the POST 404 rule and the GET delay seam, and auth_files has no modified row
