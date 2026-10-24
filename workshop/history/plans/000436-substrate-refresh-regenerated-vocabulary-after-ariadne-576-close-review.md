# Boundary Review — parley.nvim#436 (whole-issue close)

| field | value |
|-------|-------|
| issue | 436 — substrate refresh: regenerated vocabulary after ariadne#576 |
| repo | parley.nvim |
| issue file | workshop/issues/000436-substrate-refresh-regenerated-vocabulary-after-ariadne-576.md |
| boundary | whole-issue close |
| milestone | — |
| window | 1c15fc8c110f7f1c746d57f2922c685b17fa9fa3..acde0888ea717bdab41bcbe2efd4549e865d2791 |
| command | sdlc close --issue 436 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-23T21:53:10-07:00 |
| verdict | SHIP |

## Review

Checking whether the Lua reader uses the removed key.

```verdict
verdict: SHIP
confidence: high
```

This change is safe to ship. It touches two generated files under `construct/generated/vocabulary/`. In `issue.json`, it deletes one line, `"collaboration_mode": "collaboration"` under `scaffold`. In `issue.json.weave-sha256`, it updates the hash to match. I checked three things myself rather than relying on the issue log:
- The new hash file (`d4b091c8…`) matches `shasum -a 256` of the committed `issue.json`.
- The committed `issue.json` has the same parsed content (sorted JSON) as ariadne's source `pkg/vocab/issue.json` at the pinned substrate head `500f48f1`.
- No parley code still reads `scaffold.collaboration_mode`. Neither `lua/parley/issue_vocabulary.lua` nor `init.lua` uses it. The matches in `tests/unit/review_protocol_export_test.py` belong to a separate collaboration-modes export that builds its own test data.

The "Done when" clause has two parts. "main carries the regenerated files" is met by this range. "start-plan from a fresh resting branch leaves a clean tree" can only be checked after landing; it holds as long as the committed bytes match what weave regenerates, which the source comparison supports.

1. **Strengths**
   - The change is the smallest possible: one key removed, and the hash file stays consistent with the JSON (`construct/generated/vocabulary/issue.json:133`).
   - The issue log records that the regeneration was byte-identical on both runs and that no stash was used, so the provenance can be audited.
   - The issue's scope matches the diff exactly: no hand edits, nothing outside the regenerated output.

2. **Critical:** none.
3. **Important:** none.
4. **Minor:** none.
5. **Test coverage:** this is generated output only, so no new tests are needed. The `.weave-sha256` file is what detects drift, and it is correct.
6. **Architecture**
   - **ARCH-DRY: pass.** The generated vocabulary is still derived from ariadne's source and is not hand-maintained.
   - **ARCH-PURE: pass.** No code changed.
   - **ARCH-PURPOSE: pass.** Every parley reader of the vocabulary still works with the key removed, so the issue is fully delivered.
   - **ARCH-EVOLVE: pass.** The removal comes from ariadne#576, and since no parley reader used the key, nothing is lost.
7. **Plan revisions:** none.

```findings
findings: []
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"18299d6c-0707-4523-a333-f54467b2c794","repository":"github.com/xianxu/parley.nvim","issue_id":"000436","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/42f28f012aff588d","reviewed_head":"acde0888ea717bdab41bcbe2efd4549e865d2791","slot":"parley.nvim:1","requested_at":"2026-10-24T04:44:49.805427Z"},"phase":"finished","pid":98330,"started_at":"2026-10-24T04:44:49.894749Z","finished_at":"2026-10-24T04:52:31.284669Z","session_id":"77b9cc8e-8abc-4bcf-b87f-eb0edb40978a","outcome":"returned"},{"version":1,"intent":{"disposable_root":true,"id":"cce32fbf-afb6-4b49-857f-c92763c72dc9","repository":"github.com/xianxu/parley.nvim","issue_id":"000436","recipe":"small-diff-review","round":1,"attempt":2,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/42f28f012aff588d","reviewed_head":"acde0888ea717bdab41bcbe2efd4549e865d2791","slot":"parley.nvim:1","requested_at":"2026-10-24T04:52:33.198333Z"},"phase":"finished","pid":56820,"started_at":"2026-10-24T04:52:33.302771Z","finished_at":"2026-10-24T04:53:09.898155Z","session_id":"c02424a2-db69-40e1-9c9d-3eb822e2e077","outcome":"returned"}] -->

## Review preparation and protocol diagnostics

Quoted values are diagnostic data, not review verdicts.
Protocol attempt 1
reason: "missing valid findings block"
output: "The two generated files match the ariadne source byte for byte. The full test suite is slow, so I'm stopping it and running only the two vocabulary specs.\n\nThe `timeout` command doesn't exist on this machine, so the spec runs never started. I'm running them again without it.\n\nBoth vocabulary specs pass. One unrelated spec, `reap_test_orphans`, failed. I'm checking whether it touches the vocabulary file.\n\n```verdict\nverdict: SHIP\nconfidence: high\n```\n\nThis change carries the regenerated `construct/generated/vocabulary/issue.json` and its sidecar onto the branch, and it is correct. I checked it directly instead of relying on the issue log. The diff deletes exactly one line, `\"collaboration_mode\": \"collaboration\"`, from `scaffold`. The committed `issue.json` is byte-identical (`cmp`) to the pinned ariadne source `pkg/vocab/issue.json` at 500f48f1. The new `.weave-sha256` value (`d4b091c8…21cc1`) matches `shasum -a 256` of the committed `issue.json`. Nothing in parley's code or tests reads `scaffold.collaboration_mode`; the only mentions left are in `workshop/history/`. The two specs that load this file, `tests/unit/issue_vocabulary_spec.lua` and `tests/unit/issue_cards_spec.lua`, pass under `make test-unit`. Nothing blocks SHIP.\n\n1. **Strengths**\n   - The change is limited to generated output: two files, one deleted line and an updated checksum. There are no hand edits.\n   - The output matches its upstream source byte for byte, and the checksum sidecar is consistent with the committed file.\n   - The issue log is honest: no stash was used, the regeneration was byte-identical across two runs, and it names the single content change. All of this checks out against the diff.\n\n2. **Critical findings:** none.\n\n3. **Important findings:** none.\n\n4. **Minor findings:** none.\n\n5. **Test coverage notes**\n   - Both specs that read the vocabulary file pass.\n   - `tests/unit/reap_test_orphans_spec.lua` failed in this sandbox. It drives `scripts/reap-test-orphans.py` with an injected process table and never touches the vocabulary file, so it is unrelated to this change. It is a sandbox or environment failure.\n   - No new test is needed. The output derives from upstream, and the checksum sidecar already guards against drift.\n   - Done-when has two parts:\n     - **main carries the regenerated files:** verified by the diff and the byte comparison.\n     - **start-plan leaves a clean tree:** this follows from the committed files matching what regeneration produces, which I confirmed byte for byte against the pinned source. I did not run `start-plan` itself; the read-only review environment can't.\n\n6. **Architectural notes**\n   - **ARCH-DRY: pass.** The file is generated from the single upstream source; nothing in the window restates it by hand.\n   - **ARCH-PURE: pass.** There is no logic change.\n   - **ARCH-PURPOSE: pass.** The shadow-sweep found no parley consumer of `collaboration_mode` that would need updating (`lua/parley/issue_vocabulary.lua`, `lua/parley/init.lua` and both specs checked), so the issue's purpose, unblocking start-plan and abandon, is met.\n   - **ARCH-EVOLVE: pass.** This is a key removal driven by upstream ariadne#576, which owns that format change. Parley has no reader of the removed key, so nothing is lost on the parley side.\n\n7. **Plan revision recommendations:** none.\n\n```findings\n```"

truncated: false
retained-bytes: 0000003613
