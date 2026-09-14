# Workshop cleanup (#252)

## Core concepts

| Entity | Lives in | Kind | Status |
|---|---|---|---|
| Retained chat set | workshop/parley/*.md | PURE content | modified |
| Folding corpus | tests/fixtures/fold_*.md | PURE content | modified |

## Integration points

| Entity | Lives in | Kind | Status | Wraps |
|---|---|---|---|---|
| Backup and deletion | temporary cleanup script, external cleanup-backups directory | INTEGRATION | one-shot | local filesystem, SHA256 verification |
| Fold invariant runner | tests/integration/fold_invariants_spec.lua | INTEGRATION | modified | actual Neovim fold state |

No exported API or product behavior changes. Approved four-step cleanup is the design: retain seven identified product/workflow chats and four explicit demos, back up everything first, delete29personal+15tests rather than relocate. ARCH-SECURE: literal checkout child path only, assert real containment/non-symlink before removal, restrictive backup permissions; ARCH-FUNERAL: retain backup as operator-managed recovery, no automatic expiry or background process. ARCH-DRY: tests consume dedicated fixtures, not private evolving corpus.

## Execution

1. Create unique ~/.local/share/parley/cleanup-backups directory (0700), copy workshop/parley including ignored raw logs/assets and literal ./~; hash each regular file and compare source/destination before deletion. Record keep/remove names and hash manifest in backup, not public issue. No secrets printed.
2. Keep seven inventory-named product discussions plus welcome.md, basics.md, advanced.md and refractive-index demo; remove other44 root transcripts, test assets/raw log and literal ./~ only after verification. Backup includes the current edited astrophotography transcript.
3. Inspect retained branch refs. Remove branch links to discarded transcripts; normalize uniquely timestamp-matched retained paths; point refractive parent at retained basics. Preserve discussion prose and workshop tutorial versions.
4. Replace git/workshop corpus discovery and obsolete skip exception in fold_invariants_spec with explicit existing four fold fixtures plus one synthetic multi-exchange transcript. Keep model and independent raw-text oracles. Assert each fixture is readable and exact curated corpus size; test harness must work with workshop entirely absent. Add fixture to existing test traceability owner and update atlas/ui/highlights or owning fold doc if applicable.
5. Run affected mapped fold suite and lint; exact filesystem/link checks verify retained11 and all backup hashes. Record evidence, commit only issue-owned files (exclude staged operator README), fresh sdlc close, then publish separate PR if branch workflow supports it. No merge without operator direction.


## Revisions

### 2026-09-14 — Exact destructive scope and verification protocol

Authoritative checkout: `/Users/xianxu/workspace/parley.nvim`, currently branch #206. Cleanup operates here because this contains the operator's untracked/edited files; any workflow worktree is not a substitute. The eleven approved retained files are:

- `workshop/parley/2026-03-28.18-37-34.270_openshell-integration.md`
- `workshop/parley/2026-03-29.08-52-09.171_context-engineering-agents.md`
- `workshop/parley/2026-04-03.07-14-08.685.md`
- `workshop/parley/2026-04-03.07-16-59.100_what-graphviz-dot-language.md`
- `workshop/parley/2026-04-03.22-21-53.719.md`
- `workshop/parley/2026-05-03.22-29-53.828_discussion-around-parley.md`
- `workshop/parley/2026-08-15.16-56-51.344_software-similar-parley.md`
- `workshop/parley/2026-09-14.06-56-47.930_refractive-index.md`
- `workshop/parley/advanced.md`
- `workshop/parley/basics.md`
- `workshop/parley/welcome.md`

Private exact inventory and hash manifest: `/Users/xianxu/.local/share/parley/cleanup-backups/20260914-120628-workshop/inventory.json` and `manifest.json`; backup contains 2289372 bytes in59 regular files. Fourty-eight individual removed files =44 root transcripts+3PNG+1raw log. Only empty directories under the two inventory roots are removed afterward. Literal checkout `~` is now absent (operator apparently removed it); record absence, do not substitute HOME or another path.

Backup script already copied and verified source/destination; `VERIFIED` is written only after complete enumeration/hash comparison. Original recovery files never overwritten on retry. Before any deletion, preflight the full manifest: exact file-set equality, regular-file/no-symlink ancestors, each source hash and backup hash matching; new/changed/missing source, unsupported type, incomplete backup or failed IO aborts the run before deleting anything. Per-file repeat hash/type checks immediately before unlink; abort on any mutation observed, preserving backup and remaining files. An operation journal lists completed unlinks; on retry accept only those missing files already journaled, reverify all remaining original files, never rebuild the backup from a partially deleted source. This is bounded local work on2.3MB, no recursive broad removal, no process writing chats will be launched by this task. Copy/space failure cannot reach deletion.

One-shot executor and tests retained inside the private backup, not a new shipped cleanup API. Pure decisions: `validate_relative(path, approved)` rejects absolute, dot-dot, tilde, empty and unlisted targets; `verify_digest(bytes, expected)` rejects mismatches. Filesystem preflight validates exact inventory, backup completion, symlinks/file types and changed source; exercise with temporary directory fixtures for missing marker/backup, mutated file, extra file, symlink, unsafe path and successful exact removal while preserving keep files. Live apply uses fixed authoritative repo and private inventory only. Run `make test-spec SPEC=chat/exchange_model` plus lint; add a temp-index/isolated test run with workshop paths absent to establish independence. Existing model and raw-text folding oracles remain unchanged.
