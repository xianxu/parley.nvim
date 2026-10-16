# Boundary Review — parley.nvim#256 (whole-issue close)

| field | value |
|-------|-------|
| issue | 256 — Remove conflicting branch shortcut alias |
| repo | parley.nvim |
| issue file | workshop/issues/000256-remove-branch-shortcut-alias.md |
| boundary | whole-issue close |
| milestone | — |
| window | 67636021bf711c3261c8dcbf2fa96d7056443f95..9a3ace7fc4b6458c2436abb4e4347fd047646c70 |
| command | sdlc close --issue 256 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T02:27:24-07:00 |
| verdict | SHIP |

## Review

The window has no code changes; the work shipped earlier as c105136c. I'll check that claim against the head tree.

The superset test means a leftover `<M-S-CR>` in the registry would fail against the shipped config, so the registry side is covered too. Next I'll run the specs.

Running the keybinding and branch specs through the harness.

```verdict
verdict: SHIP
confidence: high
```

The pinned window contains no code changes, only two tracker commits. The removal itself landed earlier as c105136c, which is an ancestor of the head, so I checked the delivered state against the Spec at the head tree. Both default key sources carry only `<M-i>` and `<C-g>i`: `lua/parley/config.lua:421` and `lua/parley/keybinding_registry.lua:557`. In lua/, atlas/ and README, the only remaining `<M-S-CR>` is a historical comment at `tests/unit/keybindings_spec.lua:377`. The repository has no `doc/` directory. The atlas text (`atlas/ui/keybindings.md:185-196`, `atlas/chat/inline_branch_links.md:6,29`) matches the bindings. `make test-spec SPEC=ui/keybindings` passes on the head: keybindings_spec 81, branch_submit_spec 18 and branch_child_spec 63, with zero failures or errors, plus the other mapped specs (keybinding_agreement 35, single_source_sweeps 25, and the rest). The only defect is that the issue log swaps two test counts, which is Minor.

1. **Strengths**
   - Exact-list assertions pin both sources. `tests/unit/keybindings_spec.lua:338-341` checks the resolved keys, and `:370-375` checks the shipped `config.lua` itself (`dofile`), so the merged-table fallback can't hide a deleted default.
   - The shipped-default superset test (`keybindings_spec.lua:413+`) covers the registry fallback indirectly. If `<M-S-CR>` were left in the registry's `default_key`, the test would report "branch_ref loses key" because the shipped config no longer has it. Each of the two Done-when key sources has an enforcing test.
   - The help-float tests (`:343-357`, `:378-388`) check that `<M-i>` is shown first and that `(also <C-g>i)` is still advertised, which covers the "help agrees" clause.
   - The registry comment at `keybinding_registry.lua:552-556` correctly explains why `config.lua` must own the list.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - The issue log entry for 2026-10-16 swaps two test counts. It says "keybindings_spec 63 … branch_child_spec 81", but the head run shows keybindings_spec 81 and branch_child_spec 63. Within this window, that log entry is the only count claim. The 2026-09-15 totals ("Keybindings75, branch_submit17, branch_child62") were for an earlier tree, so I can't check them here.

5. **Test coverage notes:** Both Done-when clauses are tested: the key sources (shipped config plus registry, via the superset test) and the help (lead key plus alias). Branch-submission behavior is unchanged and its specs pass. The superset test is what makes the registry side fail if it regresses.

6. **Architectural notes**
   - **ARCH-DRY: pass.** The two key lists are a deliberate registry/config pair, and the superset test keeps them in sync.
   - **ARCH-PURE: pass.** The window has no logic change.
   - **ARCH-PURPOSE: pass.**
     - Every consumer I checked derives from the shipped key list: help, atlas and the tests.
     - None of them still lists the removed alias.

7. **Plan revision recommendations:** none. The plan matches the code. Correcting the swapped counts in the Log is optional.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: log-claims-unverified-against-run
    title: |
      Issue Log 2026-10-16 swaps keybindings_spec and branch_child_spec test counts
    detail: |
      The log says keybindings_spec 63 and branch_child_spec 81; the head run of make test-spec SPEC=ui/keybindings shows keybindings_spec 81 and branch_child_spec 63 (branch_submit_spec 18 is correct). It is the only count claim in this window's Log entry.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"f24e7ac5-010e-4d03-8a86-bbbe1b0137d7","repository":"github.com/xianxu/parley.nvim","issue_id":"000256","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/d79f96c41ccde4f5","reviewed_head":"9a3ace7fc4b6458c2436abb4e4347fd047646c70","slot":"parley.nvim:3","requested_at":"2026-10-16T09:23:35.311436Z"},"phase":"finished","pid":82797,"started_at":"2026-10-16T09:23:35.577728Z","finished_at":"2026-10-16T09:27:23.481678Z","session_id":"114ee46a-c93a-4e58-9749-5d61f366c9de","outcome":"returned"}] -->
