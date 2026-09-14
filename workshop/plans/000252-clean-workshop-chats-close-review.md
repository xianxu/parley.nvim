# Boundary Review — parley.nvim#252 (whole-issue close)

| field | value |
|-------|-------|
| issue | 252 — Clean workshop chat corpus |
| repo | parley.nvim |
| issue file | workshop/issues/000252-clean-workshop-chats.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0a9d11da7f0cb2caa677b8fd12c71a3c31beb5c5..cf71dcf4b981a3d969b0da342458ff54907c75a0 |
| command | sdlc close --issue 252 |
| reviewer | codex |
| timestamp | 2026-09-14T12:17:18-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The cleanup satisfies #252’s Spec and Plan. Independent inspection confirmed the exact retained inventory, recoverable backup, repaired links, and workshop-independent folding tests. The earlier #206 documentation changes included in this range also introduce no actionable findings.

1. **Strengths**
   - All 59 backup files match their SHA256 manifest; the backup directory has mode `0700`.
   - Exactly eleven approved chats remain; all 48 journaled removals are absent.
   - All six retained branch targets resolve locally.
   - Folding tests preserve both model-based and independent raw-text oracles while replacing personal inputs with explicit fixtures.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**
   - Pinned archive: mapped `chat/exchange_model` suite and four changed documentation/help specs pass.
   - Without `workshop/`: all six fold cases pass; restoring the base fold suite produces failures.
   - Seven temporary cleanup-executor tests pass.
   - Lint: zero warnings/errors across 448 files. Full suite not rerun.

6. **Architecture**
   - **ARCH-DRY — pass:** explicit fixtures and existing help reader reused.
   - **ARCH-PURE — pass:** catalog projection remains separate from filesystem/editor integration.
   - **ARCH-PURPOSE — pass:** approved cleanup inventory and test independence delivered.
   - **ARCH-MOCK — pass:** cleanup tests use isolated filesystem fixtures; no new service dependency.
   - **ARCH-CONSTRAINTS — pass:** bounded 2.3 MB cleanup; existing help limits preserved.
   - **ARCH-SECURE — pass:** verified private backup, exact removal inventory, and retained help allowlist.
   - **ARCH-ORDER — pass:** preflight precedes deletion; completed cleanup and journal agree.
   - **ARCH-FUNERAL — pass:** residue removed; backup explicitly retained for operator-managed recovery.

7. **Plan revisions:** None required.

```findings
{}
```

---

## Re-review — 2026-09-14T13:14:42-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 252 — Clean workshop chat corpus |
| repo | parley.nvim |
| issue file | workshop/issues/000252-clean-workshop-chats.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0a9d11da7f0cb2caa677b8fd12c71a3c31beb5c5..ba471812ee00aa334a5d1833f7cc943c1f31dcff |
| command | sdlc close --issue 252 |
| reviewer | codex |
| timestamp | 2026-09-14T13:14:42-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned range satisfies #252’s cleanup contract. Backup integrity, retained inventory, local branch links, and workshop-independent folding tests are verified. The range also includes #206’s documentation/help changes; inspection and targeted tests found no blocking defects.

1. **Strengths**
   - Independently verified all 59 backup SHA256 hashes, 48 journaled removals, eleven approved retained files, and six local branch links.
   - Folding tests preserve both model-derived and independent raw-text oracles.
   - Tutorial discovery reuses the existing bounded catalog and guarded file reader.
   - README, tutorials, atlas, and traceability cover the changed surfaces.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**
   - Seven cleanup safety tests pass.
   - Mapped `chat/exchange_model` tests pass.
   - Mapped `infra/starter` tests pass: 16 files, 170 assertions.
   - In an isolated tree without workshop or Git metadata, all six folding cases pass. Restoring the base folding test produces two failures, confirming meaningful regression evidence.
   - The full repository suite was not rerun.

6. **Architecture**
   - **ARCH-DRY — pass:** shared catalog and folding-policy owners remain authoritative.
   - **ARCH-PURE — pass:** catalog projection remains pure; filesystem and Neovim checks stay in integration tests.
   - **ARCH-PURPOSE — pass:** exact retention, recovery, link repair, and corpus independence are delivered.
   - **ARCH-MOCK — pass:** no new external-service dependency; filesystem safety uses temporary fixtures.
   - **ARCH-CONSTRAINTS — pass:** help limits remain enforced; cleanup is finite and inventory-bound.
   - **ARCH-SECURE — pass:** private backup permissions, hashes, path checks, and tutorial redirection rejection are verified.
   - **ARCH-ORDER — pass:** cleanup preflight precedes deletion; journaled retry is tested.
   - **ARCH-FUNERAL — pass:** debris is removed; backup retention has an explicit operator-managed lifecycle.

7. **Plan revisions:** None required. The concept tables match the delivered content and integration boundaries.

```findings
{}
```
