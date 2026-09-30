---
gate: boundary-review
issue: 307
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-30T11:56:08-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: Setup uses the nearest marker for the repo root; detect_buffer_context and issues/vision still use the git root
          detail: 'apply_repo_local (init.lua:767) now uses repo_mode.detect_root. detect_buffer_context (init.lua:1686-1692) still uses find_git_root plus the marker, so a marker-only or subdirectory-marker project is repo mode in setup but "other" in buffer context. Other git-rooted consumers of the same fact: init.lua:1062,1088; issues.lua:508,536; vision.lua:1552,1628,1662; markdown_finder.lua:315. Make them read config.repo_root, or document the split; atlas/infra/repo_mode.md''s "share this rule" overstates it.'
          family: repo-root-single-source
          round: 1
        - id: BR-2
          severity: Minor
          title: config.lua repo_chat_dir/repo_note_dir comments still say "relative to git root"
          detail: The root is now the nearest marked directory (config.lua:531-532).
          family: stale-doc-claim
          round: 1
        - id: BR-3
          severity: Minor
          title: Done-when README clause moved to atlas and operator-config clause deferred, with no Revisions entry
          detail: The minimal-config section is in atlas/infra/config.md and the README links only the parent anchor; the last Plan item is still unchecked until after merge. Record both in a Revisions section.
          family: done-when-drift-unrecorded
          round: 1
      recipe: small-diff-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-30T12:04:50-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: issues/vision/autocmds/exports now use parley.project_root(); zero_config_spec marker-only case passes at head and fails with base issues.lua (verified in scratch). Residual buffer-context split raised as a new Minor in the same family.
          round: 2
        - id: BR-2
          disposition: addressed
          note: config.lua:262,529-545 comments now say "relative to the repo root" and describe nearest-marker detection.
          round: 2
        - id: BR-3
          disposition: addressed
          note: Issue has a Revisions section (2026-09-30 close review round 1) recording the README→atlas move and deferred operator-config install.
          round: 2
      findings:
        - id: BR-4
          severity: Minor
          title: detect_buffer_context re-derives repo mode from cwd instead of config.repo_root; atlas claims it uses project_root()
          detail: '2nd finding in family repo-root-single-source (also stale-doc-claim). Rule: repo mode is decided only by setup''s config.repo_root; nothing re-derives it from cwd. Instances: init.lua:1693 (repo_mode.detect_root; wrong under repo_root=false, PARLEY_REPO_MODE=0, or an explicit repo_root elsewhere; help overlay shows "repo" in opted-out demo) and markdown_finder.lua:313-315 (inline copy of project_root, behavior-equivalent). atlas/infra/repo_mode.md:12-13 says buffer context goes through project_root(), which is false. Fix: buffer context checks type(M.config.repo_root)=="string" and non-empty; markdown_finder calls _parley.project_root(); add a not-''repo'' assertion to zero_config_spec''s opt_out probe.'
          family: repo-root-single-source
          round: 2
      recipe: small-diff-review
      blocked: false
---

# Gate ledger — parley.nvim#307 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-30T11:56:08-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `repo-root-single-source` Setup uses the nearest marker for the repo root; detect_buffer_context and issues/vision still use the git root
  apply_repo_local (init.lua:767) now uses repo_mode.detect_root. detect_buffer_context (init.lua:1686-1692) still uses find_git_root plus the marker, so a marker-only or subdirectory-marker project is repo mode in setup but "other" in buffer context. Other git-rooted consumers of the same fact: init.lua:1062,1088; issues.lua:508,536; vision.lua:1552,1628,1662; markdown_finder.lua:315. Make them read config.repo_root, or document the split; atlas/infra/repo_mode.md's "share this rule" overstates it.
- **BR-2** [Minor] `stale-doc-claim` config.lua repo_chat_dir/repo_note_dir comments still say "relative to git root"
  The root is now the nearest marked directory (config.lua:531-532).
- **BR-3** [Minor] `done-when-drift-unrecorded` Done-when README clause moved to atlas and operator-config clause deferred, with no Revisions entry
  The minimal-config section is in atlas/infra/config.md and the README links only the parent anchor; the last Plan item is still unchecked until after merge. Record both in a Revisions section.

## Round 2 — 2026-09-30T12:04:50-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — issues/vision/autocmds/exports now use parley.project_root(); zero_config_spec marker-only case passes at head and fails with base issues.lua (verified in scratch). Residual buffer-context split raised as a new Minor in the same family.
- BR-2 — addressed — config.lua:262,529-545 comments now say "relative to the repo root" and describe nearest-marker detection.
- BR-3 — addressed — Issue has a Revisions section (2026-09-30 close review round 1) recording the README→atlas move and deferred operator-config install.

### Raised

- **BR-4** [Minor] `repo-root-single-source` detect_buffer_context re-derives repo mode from cwd instead of config.repo_root; atlas claims it uses project_root()
  2nd finding in family repo-root-single-source (also stale-doc-claim). Rule: repo mode is decided only by setup's config.repo_root; nothing re-derives it from cwd. Instances: init.lua:1693 (repo_mode.detect_root; wrong under repo_root=false, PARLEY_REPO_MODE=0, or an explicit repo_root elsewhere; help overlay shows "repo" in opted-out demo) and markdown_finder.lua:313-315 (inline copy of project_root, behavior-equivalent). atlas/infra/repo_mode.md:12-13 says buffer context goes through project_root(), which is false. Fix: buffer context checks type(M.config.repo_root)=="string" and non-empty; markdown_finder calls _parley.project_root(); add a not-'repo' assertion to zero_config_spec's opt_out probe.

## Open findings

- **BR-4** [Minor] `repo-root-single-source` detect_buffer_context re-derives repo mode from cwd instead of config.repo_root; atlas claims it uses project_root()
