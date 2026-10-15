# Boundary Review — parley.nvim#333 (whole-issue close)

| field | value |
|-------|-------|
| issue | 333 — Alt+Shift+O: go back through visited files (per window), up the tree to the root |
| repo | parley.nvim |
| issue file | workshop/issues/000333-alt-shift-o-go-back-through-visited-files-per-window-up-the-tree-to-the-root.md |
| boundary | whole-issue close |
| milestone | — |
| window | 538372be03b75c9350e346f923b85366ceff809e..c69e6f8535d395c8c6043eae6fb3cd58c97cc69e |
| command | sdlc close --issue 333 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-15T12:27:46-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The main navigation workflow and mapped tests pass, and README/atlas documentation is present. One reproduced correctness bug blocks shipping: API-created splits can inherit an unrelated window’s history when their actual parent is unfocused.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: split-parent-history
    title: |
      Splits targeting an unfocused parent inherit the focused window's history
    detail: |
      lua/parley/file_history.lua:38-44 copies histories[source_window], but source_window tracks focus rather than the parent supplied to nvim_open_win. Reproduced on Neovim 0.11.7: create parent A with sessionA → answerA, focus window B with sessionB → answerB, then create an inactive split displaying A's buffer with {split="right", win=parentA}. The child starts on answerA, but its first Back reaches answerB instead of sessionA. This violates the documented parent-inheritance contract (ARCH-PURPOSE, ARCH-ORDER). Derive inheritance from the actual source parent and add regression coverage with distinct focused and parent windows.
```

1. **Strengths**

   - Ordering, cursor snapshots, branching, immutability, and retention live in a separate pure model.
   - Native switch refusal preserves unsaved text; integration coverage exercises refusal and retry.
   - Real-key tests cover linked-file traversal, consecutive Back keys, Insert mode, and queued typing.
   - Registry-derived help, README, atlas, and traceability updates accompany the new surface.

2. **Critical findings**

   - **Split-parent inheritance:** `lua/parley/file_history.lua:38–44` uses the last focused window as the parent. Resolve actual parentage before copying history. The existing test at `tests/integration/file_history_spec.lua:155` explicitly focuses the parent before creating the child, so it cannot catch this failure.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Ran the required pinned-range stat and name-status inspections, then inspected implementation, tests, docs, issue, and plan.
   - `make test-spec SPEC=ui/keybindings` passed, including all 16 adapter cases and seven model cases; the process census reported no survivors.
   - A separate native-editor probe reproduced the inheritance failure with a child displaying its parent’s existing buffer.
   - Committed-range `git diff --check` passed. The full repository suite was not rerun.

6. **Architectural notes**

   - **ARCH-DRY — Pass:** reuses the registry, editing-window predicate, and exact buffer lookup helper.
   - **ARCH-PURE — Pass:** ordering logic is independent of editor IO; model tests require no IO.
   - **ARCH-PURPOSE — Flag:** parent inheritance fails for an explicit unfocused API parent.
   - **ARCH-MOCK — Pass:** no new external service or binary dependency; editor integration uses real temporary buffers.
   - **ARCH-CONSTRAINTS — Pass:** histories are capped at 200 visits; no asynchronous fan-out is introduced.
   - **ARCH-SECURE — Pass:** native buffer switching and escaped filenames preserve the existing trust boundary.
   - **ARCH-ORDER — Flag:** focus history is treated as evidence of parent identity; the missing event sequence exposes that assumption.
   - **ARCH-FUNERAL — Pass:** window state is removed on `WinClosed`; no durable artifacts or background tasks are introduced.

7. **Plan revision recommendations**

   Add a `## Revisions` entry replacing the focused-source assumption with actual split-parent identification. Enumerate regression cases across focused/unfocused parents and active/inactive children, using distinct histories so incorrect inheritance is observable.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"96704f14-39bb-4ea7-83e2-c164f6d3f35b","repository":"github.com/xianxu/parley.nvim","issue_id":"000333","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/fdc98f8373abd1cc","reviewed_head":"c69e6f8535d395c8c6043eae6fb3cd58c97cc69e","slot":"parley.nvim:1","requested_at":"2026-10-15T19:25:58.347364Z"},"phase":"finished","pid":6551,"started_at":"2026-10-15T19:25:58.77694Z","finished_at":"2026-10-15T19:27:46.094897Z","session_id":"01a14107-4ae5-7462-b4ac-9dfd55c83169","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T12:51:24-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 333 — Alt+Shift+O: go back through visited files (per window), up the tree to the root |
| repo | parley.nvim |
| issue file | workshop/issues/000333-alt-shift-o-go-back-through-visited-files-per-window-up-the-tree-to-the-root.md |
| boundary | whole-issue close |
| milestone | — |
| window | 538372be03b75c9350e346f923b85366ceff809e..55b784e5a4a3c8f09b000b40b453feb943207e8a |
| command | sdlc close --issue 333 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-15T12:51:24-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

BR-1 is addressed under the documented narrowed inheritance contract, with verified regression evidence. The pure history model, native split inheritance, mappings, and documentation are sound. A new initialization-order defect blocks shipping: API-created windows silently lose real file visits made before their scheduled initialization runs.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      The revised issue/plan explicitly limits inheritance to native command splits. All eight unfocused-parent direction/activation assertions pass at head and fail with the pre-fix adapter loaded in memory; native split/tab inheritance also passes.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: initialization-preserves-visits
    title: |
      Deferred API initialization drops legitimate file visits
    detail: |
      lua/parley/file_history.lua:19 suppresses every observation while pending_windows is set at lines 47–55. On Neovim 0.11.7, create an active API split displaying B, then synchronously edit C and D before yielding: after initialization runs, both Back calls return false at D. Yielding immediately after creation instead produces the required D → C → B traversal. This violates any-method visit recording and the documented first-file root (ARCH-PURPOSE, ARCH-ORDER). Distinguish temporary creation observations from subsequent real visits, preserve those visits through initialization, and add deterministic tests without a yield between creation and navigation.
```

1. **Strengths**

   - The immutable model separates visit ordering, cursor snapshots, truncation, and retention from editor effects.
   - Real-editor tests cover native split independence, unsaved-buffer refusal/retry, deleted targets, and cursor clamping.
   - Insert-mode tests exercise actual mapped keys and queued typing.
   - README, atlas, configuration, and generated help cover the new surface.

2. **Critical findings**

   - **Deferred initialization loses visits:** [file_history.lua:19](/Users/xianxu/Library/Caches/sdlc/review-checkouts/acf40c2f32160616/lua/parley/file_history.lua:19). The suppression lasts until a scheduled callback, exceeding the creation operation it protects. Model initialization explicitly so temporary clones are excluded while subsequent file transitions remain observable.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - `make test-spec SPEC=ui/keybindings` passed.
   - The adapter’s 27 integration cases passed independently.
   - Range whitespace checks passed.
   - BR-1 regression probe: head passes 8/8 assertions; pre-fix adapter passes 0/8.
   - The API initialization test at [file_history_spec.lua:193](/Users/xianxu/Library/Caches/sdlc/review-checkouts/acf40c2f32160616/tests/integration/file_history_spec.lua:193) yields before navigation. Add sequences covering immediate file switches, Back, native splitting, and close before initialization completes.
   - Full `make test` was not rerun during this review.

6. **Architectural notes**

   - **ARCH-DRY — pass:** reuses registry and existing editing-window/buffer lookup helpers.
   - **ARCH-PURE — pass:** history ordering remains pure; declared PURE tests require no IO or mocks.
   - **ARCH-PURPOSE — flag:** initialization drops visits required by the issue.
   - **ARCH-MOCK — pass:** no new external service or subprocess dependency; integration exercises native editor behavior.
   - **ARCH-CONSTRAINTS — pass:** histories enforce the 200-entry bound.
   - **ARCH-SECURE — pass:** native escaped file operations and modified-buffer protection are retained.
   - **ARCH-ORDER — flag:** deferred initialization suppresses valid intervening events.
   - **ARCH-FUNERAL — pass:** window closure removes history and invalidates pending initialization tokens.

7. **Plan revision recommendations**

   Add a `## Revisions` entry defining initialization transitions and the invariant: temporary creation clones are excluded, but real visits after API creation returns must survive regardless of whether the scheduled callback has run. Record deterministic sequence coverage for that invariant.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"6841a1ac-b886-4bbf-ac3d-84de2197bed4","repository":"github.com/xianxu/parley.nvim","issue_id":"000333","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/acf40c2f32160616","reviewed_head":"55b784e5a4a3c8f09b000b40b453feb943207e8a","slot":"parley.nvim:1","requested_at":"2026-10-15T19:49:22.733163Z"},"phase":"finished","pid":82767,"started_at":"2026-10-15T19:49:22.983163Z","finished_at":"2026-10-15T19:51:20.599604Z","session_id":"01a1411c-b70a-7b32-99f5-5724e6ccb8ce","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T13:08:38-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 333 — Alt+Shift+O: go back through visited files (per window), up the tree to the root |
| repo | parley.nvim |
| issue file | workshop/issues/000333-alt-shift-o-go-back-through-visited-files-per-window-up-the-tree-to-the-root.md |
| boundary | whole-issue close |
| milestone | — |
| window | 538372be03b75c9350e346f923b85366ceff809e..8ce10d02789b1a5c8d487220a5c8eeefbcb899e9 |
| command | sdlc close --issue 333 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-15T13:08:38-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The implementation matches the revised Spec and Plan, including synchronous visit recording and the narrowed native split inheritance contract. BR-2 has reproducible regression evidence, and no new blocking findings were identified.

```findings
dispose:
  - id: BR-2
    disposition: addressed
    note: |
      The regression at tests/integration/file_history_spec.lua:193 fails at line 201 with the pre-fix adapter restored in a disposable checkout (27 pass, 1 fail). The pinned adapter passes all 28 cases. BufEnter observations now record synchronously without pending-window suppression.
  - id: BR-1
    disposition: addressed
    note: |
      Remains addressed under the revised contract: API windows inherit no parent history. The eight direction/activation cases and native split/tab inheritance cases pass; README and atlas document this distinction.
```

### 1. Strengths

- Immutable history transitions preserve independent split histories and enforce the 200-entry bound.
- Back verifies the displayed target before committing its proposed history position and preserves native modified-buffer refusal.
- Real-key tests cover linked-file traversal, restored cursors, Insert typing and repeated Back keys.
- README, atlas and registry-generated help cover the new navigation surface.

### 2. Critical findings

None.

### 3. Important findings

None.

### 4. Minor findings

None.

### 5. Test coverage notes

- `make test-spec SPEC=ui/keybindings` passed, with a clean process census.
- Independently verified BR-2 red/green in a disposable checkout; the checkout was removed afterward.
- `git diff --check` passed for the pinned range.
- The complete repository suite was not rerun during this review.

### 6. Architectural notes

- **ARCH-DRY — pass:** reuses the keybinding registry, editing-window predicate and exact-name buffer lookup.
- **ARCH-PURE — pass:** ordering lives in a pure model, tested directly without IO or mocks; editor effects remain in the adapter.
- **ARCH-PURPOSE — pass:** delivers file-level traversal, per-window positions and the revised split contract.
- **ARCH-MOCK — pass:** introduces no external binary or service dependency; integration tests exercise real Neovim behavior.
- **ARCH-CONSTRAINTS — pass:** retained histories are capped at 200 entries; no deferred initialization or background work remains.
- **ARCH-SECURE — pass:** paths use native escaped commands, and Back respects unsaved-buffer refusal.
- **ARCH-ORDER — pass:** model transitions govern visit ordering; synchronous event recording eliminates BR-2’s scheduling gap.
- **ARCH-FUNERAL — pass:** window closure removes history and restoration state; no durable artifacts are introduced.

The Core concepts table matches the code and file changes. README and atlas update gates are satisfied.

### 7. Plan revision recommendations

None. Existing BR-1 and BR-2 revisions describe the implemented contract.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"2e3a4d2c-a8f7-40ee-8928-8022a0a920cb","repository":"github.com/xianxu/parley.nvim","issue_id":"000333","recipe":"milestone-review","round":3,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/24ad1d95687239e5","reviewed_head":"8ce10d02789b1a5c8d487220a5c8eeefbcb899e9","slot":"parley.nvim:1","requested_at":"2026-10-15T20:07:02.082609Z"},"phase":"finished","pid":46099,"started_at":"2026-10-15T20:07:02.184639Z","finished_at":"2026-10-15T20:08:37.929112Z","session_id":"01a1412c-e001-7441-bafa-e68f63deed74","outcome":"returned"}] -->
