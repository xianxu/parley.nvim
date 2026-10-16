# Boundary Review — parley.nvim#238 (whole-issue close)

| field | value |
|-------|-------|
| issue | 238 — Catalog conformance cases cannot pass with the fabricated credential |
| repo | parley.nvim |
| issue file | workshop/issues/000238-catalog-conformance-cases-cannot-pass-with-the-fabricated-credential.md |
| boundary | whole-issue close |
| milestone | — |
| window | a3e476c0e5b7a7354299e7f935bbf5c940509216..1ce2a9b36d82343b3be5d654e8cc58ad6c169305 |
| command | sdlc close --issue 238 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T06:16:05-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I've read the diff and the spec. The real binary isn't on PATH here, so I'm finishing the review without a live run.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The change does what the Spec's first option describes and stays small. `boot()` takes an `opts.catalog` option. When it is set, the throwaway config gets a fabricated `claude-api-key` entry, and only the two catalog cases set it. The other ten cases keep the config they pin. Nothing real goes into the auth-dir. An API key is never refreshed, so the #197 rotation hazard doesn't apply. The SAFETY note and the atlas both explain why. One thing could not be checked here: the claim that "12 of 12 pass under `PARLEY_LIVE_GITHUB=1`" comes from the implementor's Log. No `cli-proxy-api`/`cliproxyapi` binary is on PATH in this checkout, and getting one means a network download. I am not blocking on that, because the default harness leaves these cases `pending`. The only issue I found is one inaccurate atlas sentence.

**Strengths**
- `tests/integration/cliproxy_conformance_spec.lua:126-128`: the change is opt-in and limited to the two catalog cases, so the configs the other cases pin are unchanged.
- `:16-22`: the SAFETY note gives the reason (an expired OAuth credential registers no models, measured) and names `FABRICATED_API_KEY` as one constant.
- The test assertions stayed the same. They still require a non-empty catalog, the `models/` prefix and `displayName`, and at least one row joined through `parse()`. The fix changes what the proxy is given, not what the cases check.
- ARCH-DRY passes: one constant, one branch in the shared `boot()`, and no copied boot logic.

**Critical:** none.

**Important:** none.

**Minor**
- `atlas/providers/cliproxy-managed.md:416` says "the throwaway auth-dir stays empty". That isn't true for the spec as written. `boot()` always writes the fabricated OAuth credential `claude-conformance@example.invalid.json` into that auth-dir (`cliproxy_conformance_spec.lua:103-112`), including for the catalog cases. The Log's "stays EMPTY" measurement seems to come from a scratch setup that had no OAuth file. What is actually true is that the proxy writes nothing to the auth-dir and nothing real is ever in it. The same claim appears in two places in the window: the atlas sentence and the Log bullet. The spec comment avoids it.

**Test coverage notes**
- "Done when" clause 1 (the cases pass against a real binary under `PARLEY_LIVE_GITHUB=1`) rests only on the Log. I couldn't reproduce it here because there is no binary and the network download path wasn't run. Clause 2 (no real credential) can be checked in the code: the key is a literal fabricated string, and the auth-dir only ever holds the fabricated OAuth file.
- `get()` returns on the first non-000 response. If a future binary registers the API-key catalog asynchronously after it starts listening, the first `/v1beta/models` read could come back empty and make the cases flaky. The Log reports passes on both 8.0.4 and the latest release, so I'm noting this, not raising it as a finding.

**Architecture**
- ARCH-DRY: pass.
- ARCH-PURE: pass. This is test-harness glue with no business logic.
- ARCH-PURPOSE: pass. Both catalog cases are fixed rather than narrowed, which delivers the issue's purpose, and no other case in the spec reads the catalog.

**Plan revisions:** none needed. All three checklist items are delivered in the code.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-unverified-against-code
    title: |
      The atlas says the throwaway auth-dir "stays empty", but boot() always writes a fabricated OAuth credential into it
    detail: |
      atlas/providers/cliproxy-managed.md:416 says "the throwaway auth-dir stays empty", but cliproxy_conformance_spec.lua:103-112 writes claude-conformance@example.invalid.json into that auth-dir on every boot, the catalog cases included. Reword it to "the proxy writes nothing to the throwaway auth-dir and nothing real is ever in it". Same claim in this window: the issue Log bullet "the throwaway auth-dir stays EMPTY", which was measured on a scratch setup without the OAuth file.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"b8ea1fd2-2b77-4313-a642-fa580d3b4d7f","repository":"github.com/xianxu/parley.nvim","issue_id":"000238","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/16d134027ea8c1c2","reviewed_head":"1ce2a9b36d82343b3be5d654e8cc58ad6c169305","slot":"parley.nvim:4","requested_at":"2026-10-16T13:15:28.404729Z"},"phase":"finished","pid":78587,"started_at":"2026-10-16T13:15:28.573365Z","finished_at":"2026-10-16T13:16:04.233999Z","session_id":"419c29ba-1067-48f9-b738-9b1666950b52","outcome":"returned"}] -->
