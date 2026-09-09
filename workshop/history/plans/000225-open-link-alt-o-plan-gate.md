---
gate: plan-quality
issue: 225
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-08T16:49:18-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Critical
          title: The markdown branch returns unconditionally, so the planned fall-through never fires there
          detail: |-
            OpenFileUnderCursor branches at init.lua:4426 and returns regardless of outcome
            (init.lua:4429-4431, "the markdown handler owns this case"), so Spec steps 3-4 are
            unreachable in a markdown buffer while Done-when requires them in both buffer types.
            Making it fall through promotes open_chat_reference's three currently-discarded exits
            (init.lua:4337 nil, init.lua:4344 nil, init.lua:4394 false) to load-bearing; the plan
            must say which exits fall through and which stay terminal, since falling through on
            the false case sends a resolved ref whose file is missing into gf and drops the
            diagnostic. Also, the Spec's "steps 1-3 exist" omits try_open_src_link (init.lua:4307),
            which leads the markdown chain.
          family: fallthrough-ownership-contract
          round: 1
        - id: PQ-2
          severity: Important
          title: Step 4 gets appended to two near-duplicate chains instead of one extracted helper
          detail: |-
            The chat chain (init.lua:4441-4461, branch then inline then @@) and the markdown chain
            (init.lua:4307-4340, src then inline then branch then @@) are the same logic in
            different orders. ARCH-DRY: name the consolidation in the plan — one link-follow helper
            returning an explicit outcome, with the ResolveRefOrGotoFile tail applied once at the
            caller — rather than editing both copies.
          family: duplicate-fallthrough-chain
          round: 1
        - id: PQ-3
          severity: Important
          title: Plan never says what the fall-through does in insert mode, which open_file is bound in
          detail: |-
            open_file ships modes n and i (keybinding_registry.lua:426, config.lua:384) with explicit
            insert-mode restore paths (init.lua:4511, 4587, 4602); the delegate is normal-mode only
            (keybinding_registry.lua:440) and its miss path is a bare vim.cmd("normal! gf"), which
            raises E447 out of a keymap callback on a nonexistent path. The move also widens the
            M-o slot from n-only (review_menu, keybinding_registry.lua:750) to n+i.
          family: binding-mode-set-unstated
          round: 1
        - id: PQ-4
          severity: Important
          title: Done-when leans on a collision check that is hardcoded to one key
          detail: |-
            tests/unit/keybindings_spec.lua:902-910 filters on the literal <M-g>, as do :884, :889
            and :898; it cannot catch an <M-o> re-collision and will simply go red when open_file
            leaves <M-g>. Generalize the assertion to sweep every key in reg.entries for multiple
            owners so the next chord migration is covered without a new hardcoded test.
          family: unbacked-existing-behavior-claim
          round: 1
        - id: PQ-5
          severity: Important
          title: Test row names no functions and no strategy for the risky one
          detail: |-
            "Tests: each of the four steps, in both buffer types" should name OpenFileUnderCursor
            and open_chat_reference (whose contracts change) plus one line on how "behaves as gf
            would" is asserted, since real gf needs a real file or a vim.cmd spy. Reuse the existing
            injected runner seam in artifact_ref.run_resolve (artifact_ref.lua:112-134) for the
            resolve arm rather than spawning sdlc.
          family: test-surface-unnamed
          round: 1
        - id: PQ-6
          severity: Minor
          title: Doc row omits atlas/modes/review.md, the file this change most directly falsifies
          detail: |-
            atlas/modes/review.md:55 and :199 document <M-o> as the skill picker. The plan lists
            README, atlas/ui/keybindings.md and the alt-family list (atlas/ui/keybindings.md:65,71)
            but not this one. tests/integration/review_menu_spec.lua:93,110 assert the same binding
            and will need updating.
          family: doc-consumer-enumeration
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-08T16:54:01-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: not-addressed
          note: Structural half fully addressed; exit ownership (4338 nil / 4344 nil / 4394 false) still unstated.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Extraction named with the branch_inserters precedent; one fall-through at the caller.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Mode set stated, no-wrapper claim verified at keybinding_registry.lua:1272; stopinsert decided.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: Generalised to "no alt key has two owners", with a seen-red step.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: OpenFileUnderCursor named; one strategy line each for the gf and resolve arms.
          round: 2
        - id: PQ-6
          disposition: addressed
          note: atlas/modes/review.md and review_menu_spec.lua both in the doc row.
          round: 2
      findings:
        - id: PQ-7
          severity: Minor
          title: Fall-through exits insert mode while the reference exits restore it, and the plan states only the new half
          detail: |-
            This is the 2nd finding in family `binding-mode-set-unstated`, so the ask is the
            rule, not this instance. Rule: mode-exit policy is a property of the KEY, so a plan
            that changes where one exit leaves the user must state the landing mode for every
            exit of that handler. Prevalence here: three existing exits schedule `startinsert`
            to RESTORE insert mode (init.lua:4511, 4587, 4602) — the plan cites those exact
            lines as evidence the binding is insert-bound without noticing they implement the
            opposite policy from its new `stopinsert` fall-through. Result: in insert mode
            `<M-o>` on an `@@ref@@` leaves you in insert, on a plain word in normal. That may
            well be right (composing in a chat vs reading code), but it should be a stated
            decision rather than an artifact of which branch ran.
          family: binding-mode-set-unstated
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-08T16:58:35-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: 'Three-valued contract with per-exit table; 4337/4344 fall through, 4394 terminal; src: at 4307 acknowledged.'
          round: 3
        - id: PQ-7
          disposition: addressed
          note: States the rule (landing mode follows the destination), covering the three startinsert exits and the new stopinsert together.
          round: 3
      findings:
        - id: PQ-8
          severity: Important
          title: '"The chat path duplicates most of it" is unverified — the two chains diverge in four places, three unnamed'
          detail: |-
            Second in this family, so the ask is the RULE, not this instance: a citation
            backs a location, not a characterization, and a plan that calls two paths
            duplicates must enumerate their differences with a keep/drop verdict each.
            Measured prevalence here is 4 divergences, 1 named. Markdown has src:
            (init.lua:4307), resolve_chat_path for bare names (init.lua:4352) and the
            "@@path: topic" form (init.lua:4328); chat has the directory/glob Explore arm
            and split-aware edit (init.lua:4463-4492) that markdown has never had. Executing
            "largely deleting the second copy" as written silently drops Explore on a
            directory ref in chat buffers, and leaves unstated which copy's @@ semantics
            become the single source — a hard-to-reverse choice made blind (ARCH-DRY,
            ARCH-PURPOSE).
          family: unbacked-existing-behavior-claim
          round: 3
      blocked: true
    - "n": 4
      timestamp: "2026-09-08T17:06:26-07:00"
      agent: claude
      dispose:
        - id: PQ-8
          disposition: addressed
          note: Four divergences enumerated with per-row citations that verify at init.lua:4307, 4328, 4352; chat-only Explore arm kept rather than flattened.
          round: 4
      findings:
        - id: PQ-9
          severity: Minor
          title: Row 4 bundles "split-aware edit" with the Explore arm, but markdown already has it via open_buf
          detail: |-
            3rd in family, so the ask is the RULE: an "X exists only in path A" claim must cite the
            ABSENCE in path B, not the presence in A. Measured prevalence 3. Here the cited range
            (init.lua:4463-4492) backs the directory Explore arm only; the chat chain's split-aware
            edit is at init.lua:4574-4597 and duplicates M.open_buf's logic (init.lua:2963-2984),
            which markdown already reaches. Keeping it behind is_chat carries the duplication through
            the extraction (ARCH-DRY); collapsing it onto open_buf also adds file-tracking
            (init.lua:2945-2946) and existing-window reuse (init.lua:2948-2958) to the chat path.
          family: unbacked-existing-behavior-claim
          round: 4
        - id: PQ-10
          severity: Minor
          title: The M-o consumer list is recalled, not grep-derived; omits keybinding_registry.lua:750 and three keybinding_agreement_spec assertions
          detail: |-
            2nd in family, so the RULE: a plan moving a key or identifier derives its update list from
            a grep of the literal and dispositions every hit, including each test asserting the old
            value as "will fail" / "passes for the wrong reason" / "unaffected". Measured: 13 hits in
            7 files, plan names 2 files. keybinding_registry.lua:750 is review_menu's functional
            default_key. keybinding_agreement_spec.lua:370 and :397 keep passing for the wrong reason;
            :407 (journal sidecar asserts is_nil for M-o) fails outright. Kept Minor because step 1's
            collision guard and CI both catch these loudly.
          family: doc-consumer-enumeration
          round: 4
      blocked: false
content_hash: 2df04d84a45e0685af9eabbd87856399a9e8b87eca4a2b031dff49ac0d442196
---

# Gate ledger — parley.nvim#225 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-08T16:49:18-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Critical] `fallthrough-ownership-contract` The markdown branch returns unconditionally, so the planned fall-through never fires there
  OpenFileUnderCursor branches at init.lua:4426 and returns regardless of outcome
  (init.lua:4429-4431, "the markdown handler owns this case"), so Spec steps 3-4 are
  unreachable in a markdown buffer while Done-when requires them in both buffer types.
  Making it fall through promotes open_chat_reference's three currently-discarded exits
  (init.lua:4337 nil, init.lua:4344 nil, init.lua:4394 false) to load-bearing; the plan
  must say which exits fall through and which stay terminal, since falling through on
  the false case sends a resolved ref whose file is missing into gf and drops the
  diagnostic. Also, the Spec's "steps 1-3 exist" omits try_open_src_link (init.lua:4307),
  which leads the markdown chain.
- **PQ-2** [Important] `duplicate-fallthrough-chain` Step 4 gets appended to two near-duplicate chains instead of one extracted helper
  The chat chain (init.lua:4441-4461, branch then inline then @@) and the markdown chain
  (init.lua:4307-4340, src then inline then branch then @@) are the same logic in
  different orders. ARCH-DRY: name the consolidation in the plan — one link-follow helper
  returning an explicit outcome, with the ResolveRefOrGotoFile tail applied once at the
  caller — rather than editing both copies.
- **PQ-3** [Important] `binding-mode-set-unstated` Plan never says what the fall-through does in insert mode, which open_file is bound in
  open_file ships modes n and i (keybinding_registry.lua:426, config.lua:384) with explicit
  insert-mode restore paths (init.lua:4511, 4587, 4602); the delegate is normal-mode only
  (keybinding_registry.lua:440) and its miss path is a bare vim.cmd("normal! gf"), which
  raises E447 out of a keymap callback on a nonexistent path. The move also widens the
  M-o slot from n-only (review_menu, keybinding_registry.lua:750) to n+i.
- **PQ-4** [Important] `unbacked-existing-behavior-claim` Done-when leans on a collision check that is hardcoded to one key
  tests/unit/keybindings_spec.lua:902-910 filters on the literal <M-g>, as do :884, :889
  and :898; it cannot catch an <M-o> re-collision and will simply go red when open_file
  leaves <M-g>. Generalize the assertion to sweep every key in reg.entries for multiple
  owners so the next chord migration is covered without a new hardcoded test.
- **PQ-5** [Important] `test-surface-unnamed` Test row names no functions and no strategy for the risky one
  "Tests: each of the four steps, in both buffer types" should name OpenFileUnderCursor
  and open_chat_reference (whose contracts change) plus one line on how "behaves as gf
  would" is asserted, since real gf needs a real file or a vim.cmd spy. Reuse the existing
  injected runner seam in artifact_ref.run_resolve (artifact_ref.lua:112-134) for the
  resolve arm rather than spawning sdlc.
- **PQ-6** [Minor] `doc-consumer-enumeration` Doc row omits atlas/modes/review.md, the file this change most directly falsifies
  atlas/modes/review.md:55 and :199 document <M-o> as the skill picker. The plan lists
  README, atlas/ui/keybindings.md and the alt-family list (atlas/ui/keybindings.md:65,71)
  but not this one. tests/integration/review_menu_spec.lua:93,110 assert the same binding
  and will need updating.

## Round 2 — 2026-09-08T16:54:01-07:00 (claude) — BLOCKED

### Disposed

- PQ-1 — not-addressed — Structural half fully addressed; exit ownership (4338 nil / 4344 nil / 4394 false) still unstated.
- PQ-2 — addressed — Extraction named with the branch_inserters precedent; one fall-through at the caller.
- PQ-3 — addressed — Mode set stated, no-wrapper claim verified at keybinding_registry.lua:1272; stopinsert decided.
- PQ-4 — addressed — Generalised to "no alt key has two owners", with a seen-red step.
- PQ-5 — addressed — OpenFileUnderCursor named; one strategy line each for the gf and resolve arms.
- PQ-6 — addressed — atlas/modes/review.md and review_menu_spec.lua both in the doc row.

### Raised

- **PQ-7** [Minor] `binding-mode-set-unstated` Fall-through exits insert mode while the reference exits restore it, and the plan states only the new half
  This is the 2nd finding in family `binding-mode-set-unstated`, so the ask is the
  rule, not this instance. Rule: mode-exit policy is a property of the KEY, so a plan
  that changes where one exit leaves the user must state the landing mode for every
  exit of that handler. Prevalence here: three existing exits schedule `startinsert`
  to RESTORE insert mode (init.lua:4511, 4587, 4602) — the plan cites those exact
  lines as evidence the binding is insert-bound without noticing they implement the
  opposite policy from its new `stopinsert` fall-through. Result: in insert mode
  `<M-o>` on an `@@ref@@` leaves you in insert, on a plain word in normal. That may
  well be right (composing in a chat vs reading code), but it should be a stated
  decision rather than an artifact of which branch ran.

## Round 3 — 2026-09-08T16:58:35-07:00 (claude) — BLOCKED

### Disposed

- PQ-1 — addressed — Three-valued contract with per-exit table; 4337/4344 fall through, 4394 terminal; src: at 4307 acknowledged.
- PQ-7 — addressed — States the rule (landing mode follows the destination), covering the three startinsert exits and the new stopinsert together.

### Raised

- **PQ-8** [Important] `unbacked-existing-behavior-claim` "The chat path duplicates most of it" is unverified — the two chains diverge in four places, three unnamed
  Second in this family, so the ask is the RULE, not this instance: a citation
  backs a location, not a characterization, and a plan that calls two paths
  duplicates must enumerate their differences with a keep/drop verdict each.
  Measured prevalence here is 4 divergences, 1 named. Markdown has src:
  (init.lua:4307), resolve_chat_path for bare names (init.lua:4352) and the
  "@@path: topic" form (init.lua:4328); chat has the directory/glob Explore arm
  and split-aware edit (init.lua:4463-4492) that markdown has never had. Executing
  "largely deleting the second copy" as written silently drops Explore on a
  directory ref in chat buffers, and leaves unstated which copy's @@ semantics
  become the single source — a hard-to-reverse choice made blind (ARCH-DRY,
  ARCH-PURPOSE).

## Round 4 — 2026-09-08T17:06:26-07:00 (claude) — passed

### Disposed

- PQ-8 — addressed — Four divergences enumerated with per-row citations that verify at init.lua:4307, 4328, 4352; chat-only Explore arm kept rather than flattened.

### Raised

- **PQ-9** [Minor] `unbacked-existing-behavior-claim` Row 4 bundles "split-aware edit" with the Explore arm, but markdown already has it via open_buf
  3rd in family, so the ask is the RULE: an "X exists only in path A" claim must cite the
  ABSENCE in path B, not the presence in A. Measured prevalence 3. Here the cited range
  (init.lua:4463-4492) backs the directory Explore arm only; the chat chain's split-aware
  edit is at init.lua:4574-4597 and duplicates M.open_buf's logic (init.lua:2963-2984),
  which markdown already reaches. Keeping it behind is_chat carries the duplication through
  the extraction (ARCH-DRY); collapsing it onto open_buf also adds file-tracking
  (init.lua:2945-2946) and existing-window reuse (init.lua:2948-2958) to the chat path.
- **PQ-10** [Minor] `doc-consumer-enumeration` The M-o consumer list is recalled, not grep-derived; omits keybinding_registry.lua:750 and three keybinding_agreement_spec assertions
  2nd in family, so the RULE: a plan moving a key or identifier derives its update list from
  a grep of the literal and dispositions every hit, including each test asserting the old
  value as "will fail" / "passes for the wrong reason" / "unaffected". Measured: 13 hits in
  7 files, plan names 2 files. keybinding_registry.lua:750 is review_menu's functional
  default_key. keybinding_agreement_spec.lua:370 and :397 keep passing for the wrong reason;
  :407 (journal sidecar asserts is_nil for M-o) fails outright. Kept Minor because step 1's
  collision guard and CI both catch these loudly.

## Open findings

- **PQ-9** [Minor] `unbacked-existing-behavior-claim` Row 4 bundles "split-aware edit" with the Explore arm, but markdown already has it via open_buf
- **PQ-10** [Minor] `doc-consumer-enumeration` The M-o consumer list is recalled, not grep-derived; omits keybinding_registry.lua:750 and three keybinding_agreement_spec assertions
