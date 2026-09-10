---
gate: plan-quality
issue: 224
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-09T10:49:17-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Critical
          title: Plan claims "exactly one resolver" but misses outline.lua's third naive copy
          detail: |-
            lua/parley/outline.lua:208 is a byte-identical naive resolve_path used at
            :230 (find_tree_root parent lookup), :273 and :277 (branch topic and the
            picker's child_path). A renamed parent makes find_tree_root return the
            child as root; a renamed child stores an unreadable navigation target — the
            same defect in the <M-t> tree. tests/arch/untrusted_path_spec.lua:8-12
            records that enumeration already failed on this exact file in #225.
          family: single-resolver-rule
          round: 1
        - id: PQ-2
          severity: Critical
          title: Arch guard is specified over path-joining, which none of the offending sites do
          detail: |-
            Plan row 8 guards "no module joins a chat-reference path itself", but
            chat_respond.lua:176 and outline.lua:208 both delegate to
            helper.resolve_relative_path — they join nothing, so the guard greps clean
            over a tree that still has the bug. The rule must be over resolution
            (resolve_relative_path reached with a transcript-derived reference outside
            resolve_chat_path) with a stated-reason allowlist, in the shape of
            tests/arch/untrusted_path_spec.lua:38. The "seen red" proof must re-add a
            local resolver, not a local joiner.
          family: guard-must-match-class
          round: 1
        - id: PQ-3
          severity: Important
          title: repair_reference_at_cursor omits the streaming/busy guard the current code has
          detail: |-
            The four stated guards do not include "a response is streaming into this
            buffer". _read_repair_reference defers on tasker.is_busy (init.lua:3107) and
            _slug_rename_chat refuses while busy (init.lua:3029), while a chat_lease is
            anchored on a buffer line and content-invalidated by concurrent mutation
            (chat_respond.lua:1575-1582). Name busy as a fifth guard and say whether it
            cancels, queues or ignores. Also state that the new CursorHold reads
            updatetime and does not set it — this is the plugin's first cursor autocmd.
          family: concurrent-buffer-writer
          round: 1
        - id: PQ-4
          severity: Minor
          title: Dropping referring_file changes an exported signature with six consumers
          detail: |-
            resolve_chat_path loses its third parameter; init.lua:3302, 3337, 3358 and
            4248 pass it, and exporter.lua:32 plus highlighter.lua:66 re-export the
            2-arg form. Row 6 implies this but never states the new signature.
          family: seam-signature-unstated
          round: 1
        - id: PQ-5
          severity: Minor
          title: Cited file:line anchors have drifted by 6-15 lines
          detail: |-
            resolve_chat_path is init.lua:3215 not :3200; its export :3269 not :3252;
            the repair schedule :3258 not :3241. In chat_respond.lua the parent lookup
            is :195 and the branch-match :215, not :201/:221. Every behavioral claim
            checked out; only the anchors are stale.
          family: stale-line-citation
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-09T10:52:27-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: All five consumer sites now named and routed; outline.lua:230/:273/:277 verified present.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Guard restated over resolution with allowlist shape; red-proof is a local resolver.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Busy is the fifth guard with explicit IGNORE semantics; updatetime read-not-set stated.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: New 2-arg signature stated with the four passers and two re-exporters split out.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: All re-cited anchors verified exact against the tree.
          round: 2
      blocked: false
content_hash: 3d265561cb97932a37f2a748346f28b5066b528bfd4b498e8a219e8df22618d1
---

# Gate ledger — parley.nvim#224 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-09T10:49:17-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Critical] `single-resolver-rule` Plan claims "exactly one resolver" but misses outline.lua's third naive copy
  lua/parley/outline.lua:208 is a byte-identical naive resolve_path used at
  :230 (find_tree_root parent lookup), :273 and :277 (branch topic and the
  picker's child_path). A renamed parent makes find_tree_root return the
  child as root; a renamed child stores an unreadable navigation target — the
  same defect in the <M-t> tree. tests/arch/untrusted_path_spec.lua:8-12
  records that enumeration already failed on this exact file in #225.
- **PQ-2** [Critical] `guard-must-match-class` Arch guard is specified over path-joining, which none of the offending sites do
  Plan row 8 guards "no module joins a chat-reference path itself", but
  chat_respond.lua:176 and outline.lua:208 both delegate to
  helper.resolve_relative_path — they join nothing, so the guard greps clean
  over a tree that still has the bug. The rule must be over resolution
  (resolve_relative_path reached with a transcript-derived reference outside
  resolve_chat_path) with a stated-reason allowlist, in the shape of
  tests/arch/untrusted_path_spec.lua:38. The "seen red" proof must re-add a
  local resolver, not a local joiner.
- **PQ-3** [Important] `concurrent-buffer-writer` repair_reference_at_cursor omits the streaming/busy guard the current code has
  The four stated guards do not include "a response is streaming into this
  buffer". _read_repair_reference defers on tasker.is_busy (init.lua:3107) and
  _slug_rename_chat refuses while busy (init.lua:3029), while a chat_lease is
  anchored on a buffer line and content-invalidated by concurrent mutation
  (chat_respond.lua:1575-1582). Name busy as a fifth guard and say whether it
  cancels, queues or ignores. Also state that the new CursorHold reads
  updatetime and does not set it — this is the plugin's first cursor autocmd.
- **PQ-4** [Minor] `seam-signature-unstated` Dropping referring_file changes an exported signature with six consumers
  resolve_chat_path loses its third parameter; init.lua:3302, 3337, 3358 and
  4248 pass it, and exporter.lua:32 plus highlighter.lua:66 re-export the
  2-arg form. Row 6 implies this but never states the new signature.
- **PQ-5** [Minor] `stale-line-citation` Cited file:line anchors have drifted by 6-15 lines
  resolve_chat_path is init.lua:3215 not :3200; its export :3269 not :3252;
  the repair schedule :3258 not :3241. In chat_respond.lua the parent lookup
  is :195 and the branch-match :215, not :201/:221. Every behavioral claim
  checked out; only the anchors are stale.

## Round 2 — 2026-09-09T10:52:27-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — All five consumer sites now named and routed; outline.lua:230/:273/:277 verified present.
- PQ-2 — addressed — Guard restated over resolution with allowlist shape; red-proof is a local resolver.
- PQ-3 — addressed — Busy is the fifth guard with explicit IGNORE semantics; updatetime read-not-set stated.
- PQ-4 — addressed — New 2-arg signature stated with the four passers and two re-exporters split out.
- PQ-5 — addressed — All re-cited anchors verified exact against the tree.

## Open findings

(none — every finding has been disposed)
