# Boundary Review — parley.nvim#325 (whole-issue close)

| field | value |
|-------|-------|
| issue | 325 — Image paste (Alt+v) in any markdown file, not only timestamp-named chats: sidecar assets per file, for the TL session file and QA files |
| repo | parley.nvim |
| issue file | workshop/issues/000325-image-paste-alt-v-in-any-markdown-file-not-only-timestamp-named-chats-sidecar-assets-per-file-for-the-tl-session-file-and-qa-files.md |
| boundary | whole-issue close |
| milestone | — |
| window | 2a048860b52c104a51b66e35adc9c62f26a3f7b6..8a4743ba5cc2bbaf36ee53f48d6386b873fe2e9a |
| command | sdlc close --issue 325 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-14T10:47:10-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The main paste flow works: ordinary Markdown uses sidecars, chats retain timestamp keys, and shrinking and rollback remain shared. Targeted tests and lint pass. Shipping is blocked by an attachment caller that still treats escaped URLs as disk paths, plus stale acceptance criteria.

Done-when: stale — the sole clause requires PNG output but does not cover the revised large-image shrinking/JPEG requirement.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: asset-path-resolution-consistency
    title: |
      Escaped attachment stems fail send-budget admission
    detail: |
      lua/parley/assets.lua:726 returns an encoded path, and read_bounded decodes it, but lua/parley/chat_respond.lua:403 still stats dir .. "/" .. rel directly. A foreground in-memory probe showed read_bounded successfully reading assets/answer (QA)/a.png while build_messages statted assets/answer%20%28QA%29/a.png and emitted an ENOENT omission note. The complete affected caller family is build_messages and build_messages_from_model, both through attach_question_images/asset_size; affected keys include spaces, escaped punctuation, Unicode, and literal percent signs. Centralize validated disk-path resolution in assets and use it for both stat and read, with regression coverage through both builders. ARCH-PURPOSE: the widened grammar must reach every consuming path.
  - id: new
    severity: Important
    kind: defect
    family: acceptance-criteria-contract-alignment
    title: |
      Done-when omits the revised shrinking contract
    detail: |
      workshop/issues/000325-image-paste-alt-v-in-any-markdown-file-not-only-timestamp-named-chats-sidecar-assets-per-file-for-the-tl-session-file-and-qa-files.md:33 still specifies only PNG saving/link insertion and unchanged chats, whereas Revisions:60 adds large-image shrinking and the implementation produces JPEGs. This family's complete instance in the window is the issue's sole Done-when clause. Update it to distinguish small PNG preservation from eligible large-image conversion, while retaining the chat regression requirement.
```

1. **Strengths**

   - Reuses the existing writer, shrink configuration, and asynchronous paste flow.
   - Adds meaningful session/QA paste, failed-insertion rollback, and large-image conversion tests.
   - Tests canonical escaping, Unicode, literal percent escapes, and unsafe decoded keys.
   - Updates both README and atlas for layout and owner-managed lifecycle.

2. **Critical findings**

   Escaped-path send failure above. Share one validated URL-to-disk resolver between budget stat and bounded read.

3. **Important findings**

   Acceptance criteria need the shrinking requirement above.

4. **Minor findings**

   None.

5. **Test coverage notes**

   `make -k test-spec SPEC=chat/attachments lint` passed; lint reported zero warnings/errors across 723 files. `git diff --check` passed. Existing round-trip tests stop before message-builder budget admission, leaving the reproduced failure uncovered. Live clipboard/converter checks remain opt-in.

6. **Architectural notes**

   - **ARCH-DRY: pass** — paste/save/shrink/rollback reuse existing implementations.
   - **ARCH-PURE: pass** — new key and grammar logic is pure; filesystem operations retain injected seams.
   - **ARCH-PURPOSE: flag** — both send builders still consume escaped paths using the old filesystem assumption.
   - No Core concepts table is present.

7. **Plan revision recommendations**

   Add `## Revisions` entries recording the complete stat/read consumer sweep and the updated small-PNG/large-JPEG acceptance criteria.

---

## Re-review — 2026-10-14T11:17:19-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 325 — Image paste (Alt+v) in any markdown file, not only timestamp-named chats: sidecar assets per file, for the TL session file and QA files |
| repo | parley.nvim |
| issue file | workshop/issues/000325-image-paste-alt-v-in-any-markdown-file-not-only-timestamp-named-chats-sidecar-assets-per-file-for-the-tl-session-file-and-qa-files.md |
| boundary | whole-issue close |
| milestone | — |
| window | 2a048860b52c104a51b66e35adc9c62f26a3f7b6..c4ab831355e1edcf135dd5509eef8ffdb30cd569 |
| command | sdlc close --issue 325 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-14T11:17:19-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The implementation satisfies the documented scope, and both prior findings are addressed. Shared path resolution now reaches both message builders, with regression tests independently confirmed to fail without the fix. No new findings.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      assets.resolve_path is consumed by read_bounded and chat_respond.asset_size. Both builder regressions pass at head; restoring base chat_respond.lua in a disposable archive makes both fail with zero images instead of one. The archive was removed.
  - id: BR-2
    disposition: addressed
    note: |
      The issue's Done-when at lines 33–34 now distinguishes small PNG preservation from eligible large JPEG shrinking and retains chat regression requirements. This matches the shared save/shrink implementation and paste_image_spec.lua coverage.
```

1. **Strengths**
   - One validated resolver serves budget stat and bounded reads (`lua/parley/assets.lua:1169`, `lua/parley/chat_respond.lua:400`).
   - Tests cover escaped punctuation, Unicode, literal percent escapes, unsafe keys, and both builders.
   - Ordinary Markdown reuses existing save, shrink, and rollback behavior.
   - README and atlas document layout, keybinding, and ownership.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage:** All 17 mapped attachment spec files passed; live clipboard/shrink checks remain opt-in. The mutation check produced exactly two expected builder failures. `git diff --check` passed; checkout remains clean.

6. **Architecture:** **ARCH-DRY: pass**—shared writer and resolver. **ARCH-PURE: pass**—path transformations remain pure; IO stays behind existing seams. **ARCH-PURPOSE: pass**—session/QA paste, shrinking, owner-managed lifecycle, and both send consumers are covered.

7. **Plan revisions:** None required.
