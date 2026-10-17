# Boundary Review — parley.nvim#367 (whole-issue close)

| field | value |
|-------|-------|
| issue | 367 — Attention finder: an agent rewrite of a seen or retired side doc brings it back as answered |
| repo | parley.nvim |
| issue file | workshop/issues/000367-attention-finder-an-agent-rewrite-of-a-seen-or-retired-side-doc-brings-it-back-as-answered.md |
| boundary | whole-issue close |
| milestone | — |
| window | e9a78d43e4d57f3c93721d416a5a7adbbc36d5e6..108f5a7f689d16d3c2e9e999867538e577c3eba6 |
| command | sdlc close --issue 367 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T20:06:18-07:00 |
| verdict | SHIP |

## Review

I've read the diff and the model, store, and glue code. Next I'll run the unit and integration specs to confirm they pass.

```verdict
verdict: SHIP
confidence: high
```

This change does what #367 asked for. `attention_model.scan` (`lua/parley/attention_model.lua:308`) is a pure function. It decides, from stat data and the new `saved` map, whether a side doc goes back to answered: `rewritten` for a seen entry, and `discovered` for a new or retired one, where `discovered` now un-retires the path. `attention.discover` is now only IO: it lists the folder and stats each file, and reads frontmatter only for the files the rule picks. The `BufWritePost` hook records the operator's own saves through the one `apply`. Every Done-when item is delivered: the model specs for rewrite-after-seen, operator save, write at or before seen, retired coming back, and an operator-created doc; one integration spec through `attention.open`; and the atlas rule. I ran `make test-spec SPEC=ui/attention_finder` at the pinned head and all five mapped spec files passed (26, 12, 40, 6 and 17 tests, 0 failures, 0 errors). Nothing blocks shipping. What's left are Minor notes about how the `saved` map is bounded and a one-time effect on upgrade.

**1. Strengths**
- **Pure rule, thin IO.** `Model.scan` takes `{path, parent, mtime_sec, mtime_id}` and returns events. The glue `attention.lua:121-153` only stats and reads file heads, and keeps the old cost bound: frontmatter is read only for the files the rule picks.
- **Typed agent-write signal.** Comparing the whole `"sec.nsec"` string tells an operator save apart from an agent write in the same second. The spec at `tests/unit/attention_model_spec.lua:506-512` checks this explicitly.
- **The handler checks its own preconditions.** `handlers.rewritten` refuses entries that are not side docs, not seen, or written at or before `seen_at`, so a stray event does nothing. This is tested at `attention_model_spec.lua:520-522`.
- **Store parsing.** It types `saved` at the boundary and warns once for bad values (`attention_store.lua:73-76`). The spec with two store instances covers the case where the operator runs several parley Neovims.
- **Honest limits.** The atlas states the boundaries: an outside editor counts as an agent write, the comparison against `seen_at` is at whole seconds, and only current entries' folders are scanned.

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings**
- **`saved` is only bounded at sweep (ARCH-FUNERAL).** `handlers.saved` adds a row for every save of a file in any `.side/` folder, even unrelated ones and non-`.md` files. Pruning happens only in `handlers.sweep`, which runs on each finder open. Between opens the map has no bound, yet the atlas says "at most 256". Fix sketch: call `prune_saved` in `handlers.saved` too, or narrow `M.saved` to `*.md`.
- **The 256 cap can drop saves a scan still needs.** The kept set can be larger than 256: up to 256 entries plus up to 256 retired paths plus files in side folders. When that happens, `prune_saved` drops the oldest saves, and the operator's dropped save then reads as an agent write, so the doc shows answered when it shouldn't. Also, the sort uses `tonumber("sec.nsec")` without zero-padded nanoseconds, so order within one second is only approximate.
- **One-time effect on upgrade.** Stores written before #367 have no `saved` map. So a seen or retired side doc the operator edited before the upgrade comes back as answered once. This isn't written down in the atlas or the Log.
- **Plan wording.** The Plan says `saved` "is pruned on every write", but the code prunes only at sweep. Its Steps entry also lists "traceability", which needed no change because the existing mappings already cover the edited specs.

**5. Test coverage notes**
- The unit specs cover each branch of `scan`: rewritten, operator save, write at or before seen, waiting or answered entries, retired with an operator save, retired with an agent write, and operator-created versus agent-created docs. They also cover prune scoping and the cap.
- The integration spec runs the real `BufWritePost`, `:w`, a rewrite, sweep and retire, and coming back, all through `attention.open`.
- The Log's mutation checks line up with what the specs would catch.
- Not covered: losing a `saved` apply because the store is busy, which would read as an agent write. That path logs a warning, so the failure is visible.

**6. Architectural notes**
- **ARCH-DRY: pass.** Paths are normalised the same way as in `viewed` (`fnamemodify :p`). `mtime_id` is one helper. The `since` rule moved into `scan` rather than being copied. A small repeat: the `discovered` event is built twice in `scan`.
- **ARCH-PURE: pass.** `scan` and the handlers are pure. The one exception is `prune_saved` calling `require("parley.document_move_plan").side_path`, which is a pure path helper.
- **ARCH-PURPOSE: pass.** All parts of the Spec are delivered; nothing is deferred.
- **ARCH-MOCK: pass.** The only dependency is the filesystem, and the tests use real temp files and the real store lease.
- **ARCH-CONSTRAINTS: pass.** The cost on open is a stat per file, with heads read only for the files the rule picks, and the atlas states this.
- **ARCH-SECURE: pass.** `saved` is typed when the store file is parsed.
- **ARCH-ORDER: pass.** Every change goes through `apply` and the transition function. Cross-editor saves are serialised by the lease, and a lost save warns visibly.
- **ARCH-FUNERAL: minor flag** (the first Minor finding above).

**7. Plan revision recommendations**
- Add a `## Revisions` entry saying that `saved` is pruned and capped at sweep (finder open), not on every write. Also note the one-time effect on upgrade for stores without `saved`.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: writer-unbounded-between-prunes
    title: |
      saved map grows unbounded between sweeps; atlas claims at most 256
    detail: |
      handlers.saved records every BufWritePost of any file in any .side/ folder, including non-md and unrelated folders, and only handlers.sweep (finder open) prunes and caps. Prune or cap in handlers.saved too, or narrow M.saved to *.md.
  - id: new
    severity: Minor
    kind: defect
    family: cap-smaller-than-live-set
    title: |
      saved cap of 256 can drop live saves, so operator edits resurface as agent writes
    detail: |
      The relevant set (256 entries, 256 retired paths, plus side-folder files) can exceed LIMIT, and a pruned save makes the operator's edit read as an agent rewrite. The sort uses tonumber of sec.nsec without zero-padded nanoseconds, so order within one second is approximate.
  - id: new
    severity: Minor
    kind: defect
    family: undocumented-upgrade-behavior
    title: |
      Pre-367 stores have no saved map; operator-edited seen or retired side docs resurface once
    detail: |
      Not noted in the atlas or Log. Add a line under Limits or a plan Revisions entry.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"134ba49c-74b9-480b-bdbf-94b8d84d7285","repository":"github.com/xianxu/parley.nvim","issue_id":"000367","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/f6fe7c940e57552e","reviewed_head":"108f5a7f689d16d3c2e9e999867538e577c3eba6","slot":"parley.nvim:3","requested_at":"2026-10-17T03:03:59.805117Z"},"phase":"finished","pid":29345,"started_at":"2026-10-17T03:03:59.947547Z","finished_at":"2026-10-17T03:06:15.351266Z","session_id":"6239d6a9-7714-47b3-8529-24ca2a17842c","outcome":"returned"}] -->
