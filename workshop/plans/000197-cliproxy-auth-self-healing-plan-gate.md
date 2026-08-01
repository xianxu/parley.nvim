---
gate: plan-quality
issue: 197
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-08-01T00:58:34-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Critical
          title: Task 5's config_drift restart is dead code — ensure_running rewrites the file before the check
          detail: |-
            ensure_running calls write_rendered_config() first (cliproxy.lua:287-291), which
            overwrites config_path(); config_drift() (cliproxy.lua:396-415) then compares that
            same file to a fresh render, so it is always false inside the health_probe callback
            and Task 5's own test cannot pass. It also never observes the running proxy's loaded
            config. Capture drift before the write, or key the restart off the no_management_route
            404 that Task 4 already models.
          round: 1
        - id: PQ-2
          severity: Critical
          title: classify_response never reads http_status, so ten broad patterns run over successful bodies
          detail: |-
            check_auth_failure runs on every completed response (dispatcher.lua:310-313). Patterns
            like "authentication_error", "401 unauthorized", "payment_required" and "model
            unavailable" will match ordinary assistant output — a chat about this issue is the
            obvious trigger — and post-M2 drive decide into prompt_login, breaking the Done-when
            "only a genuinely dead credential prompts". Gate on non-2xx and state the strategy as a
            property (arbitrary body x status, nil for every 2xx) rather than seven hand-picked cases.
          round: 1
        - id: PQ-3
          severity: Important
          title: No path carries the cliproxy channel for the expired/401 verdict
          detail: |-
            The 401 body has no provider or model, the dispatcher's failure table
            (dispatcher.lua:403-409) carries no model, and auth_files defaults to a hardcoded
            "claude". resolve_login_provider (cliproxy_config.lua:154) needs a model. State how the
            request's model reaches recover, and extend the failure/recover_query contract to carry it.
          round: 1
        - id: PQ-4
          severity: Important
          title: Plan never says whether check_auth_failure survives M2 alongside recover_query
          detail: |-
            After M2 both finish_stdout (dispatcher.lua:304-314) and the failure branch
            (dispatcher.lua:397-427) react to the same auth failure, with only the module-local
            _login_prompt_active flag between them — duplicated policy, ARCH-DRY. Relatedly Task 6's
            "pass the HTTP status through at dispatcher.lua:311-313" is not implementable: http_status
            is computed in the terminal closure (dispatcher.lua:393-401) and is not in scope there.
            Name the single owning seam.
          round: 1
        - id: PQ-5
          severity: Minor
          title: decide's DRY rationale names the ParleyProxy models prompt as a consumer, but no task touches it
          detail: |-
            init.lua:412-419 still hand-rolls its own login prompt. Per ARCH-PURPOSE, either schedule
            the collapse onto decide or declare it an explicit non-goal.
          round: 1
        - id: PQ-6
          severity: Minor
          title: Task 15's login tests need fake modes the integration-points table does not list
          detail: |-
            The fake_cliproxy row lists only "management + auth states", but Task 15 tests success,
            callback-port-taken, process-dies-early and timeout. Name the login modes: emit the
            -no-browser authorize URL on stdout, write a credential into the auth-dir on success,
            exit non-zero early, hang for the timeout case.
          round: 1
        - id: PQ-7
          severity: Minor
          title: Rendering secret-key also registers cliproxy's control panel; consider disabling it by default
          detail: |-
            Task 3 preserves an operator-set disable-control-panel but never sets it. Parley only needs
            the JSON route, so defaulting disable-control-panel to true keeps the new loopback surface
            minimal.
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-08-01T01:05:52-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: config_drift task dropped; the no_management_route 404 from the running proxy replaces it.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Status gate is now an invariant returning nil for every 2xx, pinned by a property test.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: failure table gains model from payload.model, in scope at dispatcher.lua:163; classify_response backfills.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: check_auth_failure and detect_auth_failure are deleted; recover_query is the single owner, moved into M1.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: Task 12 collapses the init.lua:408-419 prompt onto decide.
          round: 2
        - id: PQ-6
          disposition: addressed
          note: Login modes named success / port_taken / dies_early / hangs.
          round: 2
        - id: PQ-7
          disposition: addressed
          note: disable-control-panel defaults true when parley renders the key.
          round: 2
      findings:
        - id: PQ-8
          severity: Critical
          title: recover_query's contract with on_error is unstated; as ordered it tears down the chat leg before any retry lands
          detail: |-
            Task 6 places recover_query "before on_error", but on_error is terminal: chat_respond.lua:2046-2065
            runs pending_session:failure, chat_presentation.lua:174-181 finishes the session, and
            teardown_chat_leg (chat_respond.lua:1753-1765) clears the lease and notifies the raw body. Recovery
            is async, so on_error always wins and Done-when "repaired and retried without a prompt" cannot hold;
            the retry's fresh qid (dispatcher.lua:175) has no live session. State the ownership contract — a
            synchronous claim, or a give_up continuation with a bounded timeout. Also: retry cannot call
            start_query (a local in D.query, dispatcher.lua:452) and query is not self-referencable
            (dispatcher.lua:163 uses `local query = function`); the entry point must be threaded in.
          round: 2
        - id: PQ-9
          severity: Minor
          title: Tasks 1-3 inline full implementation source and a complete test file — compress to strategy lines
          detail: |-
            Keep the pattern-ordering constraint and one strategy line per risky function (classify_response →
            arbitrary body x status property; classify_auth_files → rank collision across multi-record lists;
            parse_peers → malformed ps output). The rest restates a diff that is stale on arrival.
          round: 2
      blocked: true
---

# Gate ledger — parley.nvim#197 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-08-01T00:58:34-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Critical] Task 5's config_drift restart is dead code — ensure_running rewrites the file before the check
  ensure_running calls write_rendered_config() first (cliproxy.lua:287-291), which
  overwrites config_path(); config_drift() (cliproxy.lua:396-415) then compares that
  same file to a fresh render, so it is always false inside the health_probe callback
  and Task 5's own test cannot pass. It also never observes the running proxy's loaded
  config. Capture drift before the write, or key the restart off the no_management_route
  404 that Task 4 already models.
- **PQ-2** [Critical] classify_response never reads http_status, so ten broad patterns run over successful bodies
  check_auth_failure runs on every completed response (dispatcher.lua:310-313). Patterns
  like "authentication_error", "401 unauthorized", "payment_required" and "model
  unavailable" will match ordinary assistant output — a chat about this issue is the
  obvious trigger — and post-M2 drive decide into prompt_login, breaking the Done-when
  "only a genuinely dead credential prompts". Gate on non-2xx and state the strategy as a
  property (arbitrary body x status, nil for every 2xx) rather than seven hand-picked cases.
- **PQ-3** [Important] No path carries the cliproxy channel for the expired/401 verdict
  The 401 body has no provider or model, the dispatcher's failure table
  (dispatcher.lua:403-409) carries no model, and auth_files defaults to a hardcoded
  "claude". resolve_login_provider (cliproxy_config.lua:154) needs a model. State how the
  request's model reaches recover, and extend the failure/recover_query contract to carry it.
- **PQ-4** [Important] Plan never says whether check_auth_failure survives M2 alongside recover_query
  After M2 both finish_stdout (dispatcher.lua:304-314) and the failure branch
  (dispatcher.lua:397-427) react to the same auth failure, with only the module-local
  _login_prompt_active flag between them — duplicated policy, ARCH-DRY. Relatedly Task 6's
  "pass the HTTP status through at dispatcher.lua:311-313" is not implementable: http_status
  is computed in the terminal closure (dispatcher.lua:393-401) and is not in scope there.
  Name the single owning seam.
- **PQ-5** [Minor] decide's DRY rationale names the ParleyProxy models prompt as a consumer, but no task touches it
  init.lua:412-419 still hand-rolls its own login prompt. Per ARCH-PURPOSE, either schedule
  the collapse onto decide or declare it an explicit non-goal.
- **PQ-6** [Minor] Task 15's login tests need fake modes the integration-points table does not list
  The fake_cliproxy row lists only "management + auth states", but Task 15 tests success,
  callback-port-taken, process-dies-early and timeout. Name the login modes: emit the
  -no-browser authorize URL on stdout, write a credential into the auth-dir on success,
  exit non-zero early, hang for the timeout case.
- **PQ-7** [Minor] Rendering secret-key also registers cliproxy's control panel; consider disabling it by default
  Task 3 preserves an operator-set disable-control-panel but never sets it. Parley only needs
  the JSON route, so defaulting disable-control-panel to true keeps the new loopback surface
  minimal.

## Round 2 — 2026-08-01T01:05:52-07:00 (claude) — BLOCKED

### Disposed

- PQ-1 — addressed — config_drift task dropped; the no_management_route 404 from the running proxy replaces it.
- PQ-2 — addressed — Status gate is now an invariant returning nil for every 2xx, pinned by a property test.
- PQ-3 — addressed — failure table gains model from payload.model, in scope at dispatcher.lua:163; classify_response backfills.
- PQ-4 — addressed — check_auth_failure and detect_auth_failure are deleted; recover_query is the single owner, moved into M1.
- PQ-5 — addressed — Task 12 collapses the init.lua:408-419 prompt onto decide.
- PQ-6 — addressed — Login modes named success / port_taken / dies_early / hangs.
- PQ-7 — addressed — disable-control-panel defaults true when parley renders the key.

### Raised

- **PQ-8** [Critical] recover_query's contract with on_error is unstated; as ordered it tears down the chat leg before any retry lands
  Task 6 places recover_query "before on_error", but on_error is terminal: chat_respond.lua:2046-2065
  runs pending_session:failure, chat_presentation.lua:174-181 finishes the session, and
  teardown_chat_leg (chat_respond.lua:1753-1765) clears the lease and notifies the raw body. Recovery
  is async, so on_error always wins and Done-when "repaired and retried without a prompt" cannot hold;
  the retry's fresh qid (dispatcher.lua:175) has no live session. State the ownership contract — a
  synchronous claim, or a give_up continuation with a bounded timeout. Also: retry cannot call
  start_query (a local in D.query, dispatcher.lua:452) and query is not self-referencable
  (dispatcher.lua:163 uses `local query = function`); the entry point must be threaded in.
- **PQ-9** [Minor] Tasks 1-3 inline full implementation source and a complete test file — compress to strategy lines
  Keep the pattern-ordering constraint and one strategy line per risky function (classify_response →
  arbitrary body x status property; classify_auth_files → rank collision across multi-record lists;
  parse_peers → malformed ps output). The rest restates a diff that is stale on arrival.

## Open findings

- **PQ-8** [Critical] recover_query's contract with on_error is unstated; as ordered it tears down the chat leg before any retry lands
- **PQ-9** [Minor] Tasks 1-3 inline full implementation source and a complete test file — compress to strategy lines
