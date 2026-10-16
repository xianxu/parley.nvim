# Boundary Review — parley.nvim#204 (whole-issue close)

| field | value |
|-------|-------|
| issue | 204 — a config change to api_keys silently does not take effect: the defaults table is replaced, and the vault pins the first secret it saw |
| repo | parley.nvim |
| issue file | workshop/issues/000204-secret-resolution-surprises.md |
| boundary | whole-issue close |
| milestone | — |
| window | be26f430498624ce9064b693ddc56f4ead113097..d76992f3d584e5b79b11ecf15057c4cc7eefaa00 |
| command | sdlc close --issue 204 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T18:30:39-07:00 |
| verdict | SHIP |

## Review

Diff and vault/init code are read. Next I'm running the test suite to check the claims.

Touched specs pass. Now checking that the tests fail when the vault reset is reverted.

Mutation check confirms the reset is pinned (3 failures when reverted). Now checking `port_identity`'s return shape against `mismatch_message`.

```verdict
verdict: SHIP
confidence: high
```

This change does what the issue asks. **D1:** #307 had already fixed it, and `tests/unit/setup_api_keys_spec.lua` now pins the fix with three cases: a partial table, `false`, and a re-run. **D2:** `vault.setup` now clears `secrets` and `_obfuscated_secrets`, and I confirmed the tests depend on it. When I commented out the `secrets = {}` reset in a throwaway copy, three cases failed (setup_api_keys ×2 and vault F1). With the line restored, all five touched specs pass. **The restart notice** now names the setup time its key came from, and an integration test checks the wording. **The mismatch message** is now a pure function, `mismatch_message`, unit-tested for all three identity cases. It is only called on the 401 branch, so the synchronous ps+lsof read stays off the normal dispatch path. The plan's four items and the three Done-when clauses are all delivered. Nothing blocks SHIP. What's left is two Minor edge cases in the reset (derived state survives it) and a wiring test that can't tell the branches apart.

1. **Strengths**
   - `lua/parley/vault.lua:31-37`: the reset happens in `vault.setup`, before any `add_secret` in the same `setup{}`. First-write-wins inside one setup is unchanged (vault A3 still passes), and `api_keys` still beats `provider.secret` because `init.lua:604-608` runs before `dispatcher.setup` at `:622`.
   - `lua/parley/cliproxy_release.lua:289-305`: `mismatch_message` is pure and takes the port and command prefix as arguments. When parley can't tell who started the proxy, the message gives both fixes instead of guessing.
   - `lua/parley/cliproxy.lua:779-784`: the ps+lsof read happens only after a 401 has already come back, which keeps the hot-path note in the existing comments true.
   - The tests cover real behaviour: the edit cycle `parley_local` → `parley-local` → back to the default reads the same vault name the renderer reads (`get_secret_name("cliproxyapi")`).

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - **Derived state survives the reset.** Two places in this window:
     - (a) `V._state.copilot_bearer` and its on-disk `vault_state.json` are not cleared. A re-run setup with a different `copilot` key keeps using the old bearer until it expires. That contradicts the atlas line at `atlas/infra/vault.md:13-14`, which says re-sourcing "takes effect on the next request".
     - (b) A `resolve_secret` command still running when setup re-runs writes `secrets[name] = content` (`vault.lua:~140`) into the new table. That can overwrite the new setup's value.
     - Fix sketch: clear `_state` in `setup` too (or key the bearer cache to the secret it came from). Also add a setup generation counter that a resolver callback checks before writing.
   - **The wiring test doesn't tell the branches apart.** `tests/integration/cliproxy_lifecycle_spec.lua:342` asserts `api_keys.cliproxyapi`. That text appears in both the `ours=false` and the could-not-tell messages, so the test would still pass if `port_identity`'s result were never used. No integration test drives the `ours=true` (stale proxy) message through `ensure_running`.
   - **ARCH-DRY:** `(require("parley").config or {}).cmd_prefix or "Parley"` now appears three times in `cliproxy.lua` (`:782`, `:1136`, `:1455`) and once in `agent_picker.lua:213`. It could be a single `cmd_prefix()` helper.

5. **Test coverage notes:** The new unit tests use no IO beyond `setup`'s temp dirs, and the reset is pinned (confirmed with the mutation check above). The restart notice is checked by regex, including the HH:MM:SS format. The only coverage gap is the identity wiring in the 401 branch, covered in the second Minor item.

6. **Architecture**
   - **ARCH-DRY:** flag, Minor only (the prefix lookup above). No other duplication.
   - **ARCH-PURE:** pass. The choice of message is pure, and the IO (`port_identity`) stays in the thin shell, called only on the failure branch.
   - **ARCH-PURPOSE:** pass, with one partial sweep. The purpose was "a re-run setup replaces what's in the vault". That holds for the secret store, but not for state derived from secrets (the copilot bearer and in-flight resolvers), as listed under Minor.

7. **Plan revisions:** none needed; the plan matches the code. You could add a revision noting that the reset doesn't cover the copilot bearer cache, or narrow the atlas wording to match.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: setup-reset-leaves-derived-secret-state
    title: |
      vault.setup reset does not cover state derived from secrets: copilot bearer cache and in-flight resolvers
    detail: |
      Instances in window: (a) V._state.copilot_bearer and the on-disk vault_state.json survive vault.setup, so a re-run setup with a new copilot key keeps the old bearer until it expires, which contradicts atlas/infra/vault.md saying re-sourcing "takes effect on the next request". (b) a resolve_secret command still running across a setup re-run writes secrets[name]=content into the new table and overwrites the new value. Fix: clear _state in setup (or key the bearer to its source secret), and have the resolver callback check a setup generation counter before writing.
  - id: new
    severity: Minor
    kind: defect
    family: wiring-assertion-not-discriminating
    title: |
      The lifecycle 401 assertion matches both the ours=false and could-not-tell messages, so the port_identity wiring is unpinned
    detail: |
      tests/integration/cliproxy_lifecycle_spec.lua:342 checks only for api_keys.cliproxyapi, which appears in both non-ours branches of mismatch_message. The test would still pass if ensure_running passed a constant identity. No integration test reaches the ours=true stale-proxy message. Assert the branch-specific text, or make the identity read injectable.
  - id: new
    severity: Minor
    kind: defect
    family: arch-dry-cmd-prefix-lookup
    title: |
      ARCH-DRY: the cmd_prefix lookup is repeated three times in cliproxy.lua (782, 1136, 1455) plus agent_picker.lua:213
    detail: |
      (require("parley").config or {}).cmd_prefix or "Parley" is copy-pasted. Pull it into one local helper.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"8abbacc5-0c7c-484a-9eb0-8530933c2e87","repository":"github.com/xianxu/parley.nvim","issue_id":"000204","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/af3ba2b83126c07d","reviewed_head":"d76992f3d584e5b79b11ecf15057c4cc7eefaa00","slot":"parley.nvim:4","requested_at":"2026-10-16T01:28:27.687286Z"},"phase":"finished","pid":98388,"started_at":"2026-10-16T01:28:27.783648Z","finished_at":"2026-10-16T01:30:39.413748Z","session_id":"01a220eb-7af7-4abc-9b4d-3e7cd6eb3da5","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T20:39:40-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 204 — a config change to api_keys silently does not take effect: the defaults table is replaced, and the vault pins the first secret it saw |
| repo | parley.nvim |
| issue file | workshop/issues/000204-secret-resolution-surprises.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3d0c2369d1e25b61819b3554cdf1fd7950e7823f..cb9bbbb3d181b448faa66b652aae6c56272ff70f |
| command | sdlc close --issue 204 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T20:39:40-07:00 |
| verdict | SHIP |

## Review

Diff read; now checking setup ordering in init.lua and other vault callers.

Now running the touched specs and a mutation check on the port_identity wiring.

Runner works (vault_spec 34/34 pass); running the remaining touched specs.

All green. Now mutation checks for the claimed fixes (BR-1, BR-2).

```verdict
verdict: SHIP
confidence: high
```

All three prior findings are fixed, and mutation tests back each fix. The work meets the issue's purpose:

- **D1 (default lost when you set other keys):** fixed earlier by #307. This window adds the regression test that pins it.
- **D2 (vault kept the first secret it saw):** `vault.setup` now clears the secrets, the obfuscated copies and `_state`, and records `loaded_at`. It also bumps a generation counter that discards results from secret commands or token fetches still running from an earlier setup.
- **401 message:** a pure `mismatch_message` now separates "your config is wrong" from "the proxy is stale". It is wired into the failure branch only.

I ran the five touched specs at head and all pass: vault 34/34, setup_api_keys 3/3, cliproxy_release 53/53, lifecycle 56/56, command 19/19. Reverting each claimed fix turns its tests red. The only new finding is a Minor comment-placement nit, which does not block SHIP.

1. **Strengths**
   - `vault.lua:40-44`: the reset sits in the one place `setup{}` controls. Within a single setup, the first value still wins (`add_secret` unchanged), so `api_keys` still beats a `provider.secret` (`dispatcher.lua:67`, which runs after `vault.setup` at `init.lua:604`).
   - `vault.lua:187-217`: keying the copilot bearer to `sha256(copilot key)` also covers the disk cache across restarts. An old cache file with no `source` just triggers one extra fetch, so no migration is needed.
   - `cliproxy_release.lua:290`: `mismatch_message` is pure and unit-tested on all three identities with no mocks. The ps+lsof read happens only on the 401 branch, off the normal request path (ARCH-PURE).
   - `cliproxy_lifecycle_spec.lua:336-375`: the `fake_ps` stub decides the process identity, so each of the three cases asserts text only its own branch produces, plus the absence of the other branch's text.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `cliproxy.lua:749-754`: the forward declaration `local port_identity` sits between `ensure_running`'s `---` doc block (with its `@param` lines) and the function. LuaLS now attaches that doc to the variable. Fix: move the declaration above the doc block. This is the only hoist in the window that separates a doc comment from its function; I checked the vault.lua insertions (`generation`, `bearer_source`) and they are clean.

5. **Test coverage notes.** Mutation results on this checkout, all restored afterwards:
   - Passing a constant identity at the 401 call site fails 2 lifecycle cases.
   - Removing the generation check in `resolve_secret` fails F3.
   - Removing both the bearer `source` check and the fetch generation check fails V3 and V4.

   Each Done-when clause is exercised in both of its states: the default is kept vs. `false` drops it; the edit takes effect vs. the restart notice says it can't; ours vs. foreign vs. unknown.

6. **Architectural notes**
   - ARCH-DRY: pass. The three repeated `cmd_prefix` lookups in cliproxy.lua are now one helper. `agent_picker.lua:226` reads a `plugin.config` passed in by its caller, in a different module, so a cross-module helper isn't warranted.
   - ARCH-PURE: pass. The message choice is pure; the identity read is the thin IO part.
   - ARCH-PURPOSE: pass. Every consumer of the secret store goes through `setup{}`: `get_secret`, the cliproxy render, the copilot bearer, and in-flight resolvers. No hand-copied secret state is left.
   - A request in flight across a re-run setup now fails instead of retrying. That trade-off is intended and documented in `atlas/infra/vault.md`.

7. **Plan revision recommendations:** none.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      vault.setup clears _state and bumps generation (vault.lua:40-44); fences at vault.lua:138 and 248; bearer keyed by sha256 at 217/269. Removing the fences or source check fails F3, V3/V4.
  - id: BR-2
    disposition: addressed
    note: |
      Lifecycle 401 split into ours/foreign/unknown via fake_ps with branch-specific asserts; a constant identity at cliproxy.lua:787 fails 2 cases (verified by mutation).
  - id: BR-3
    disposition: addressed
    note: |
      cmd_prefix() helper at cliproxy.lua:61 now used at 787, 1140, 1459; agent_picker reads an injected plugin.config in another module, acceptable.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: hoist-detaches-doc-comment
    title: |
      Forward declaration of port_identity splits ensure_running's doc block from the function
    detail: |
      cliproxy.lua:749-754: the triple-dash doc and param annotations now attach to local port_identity, not M.ensure_running. Move the declaration above the doc block. Only instance in the window; the vault.lua insertions do not detach any doc comment.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"b7837796-c11b-4be0-a5b1-38e57a526f2d","repository":"github.com/xianxu/parley.nvim","issue_id":"000204","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/007c661a4c679597","reviewed_head":"cb9bbbb3d181b448faa66b652aae6c56272ff70f","slot":"parley.nvim:4","requested_at":"2026-10-16T03:37:12.642235Z"},"phase":"finished","pid":35792,"started_at":"2026-10-16T03:37:12.821846Z","finished_at":"2026-10-16T03:39:39.438116Z","session_id":"b6989cdb-588e-4847-bf99-8000e8de873b","outcome":"returned"}] -->
