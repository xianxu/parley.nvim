---
id: 000294
status: codecomplete
created: 2026-09-27
updated: 2026-10-01
estimate_hours:
github_issue:
started: 2026-10-01T14:36:23-07:00
actual_hours: 3.38
tracker:
    version: 1
    handoff:
        token: move-7054a25d27ae
        repository: github.com/xianxu/parley.nvim
        source_branch: refs/heads/000293-writer-folds-tool-test-flake
        source_base: fbade52193d887f1fc9cb91597b34cb3532ddf69
        source_head: 7b34f8aadd8e8e374274080188841b9a92e6b6b5
        source_path: workshop/issues/000294-parallel-load-spec-failures.md
        source_blob: 51434e6761b17ded2e50835e35657ab3819494db
        destination: workshop/issues/000294-parallel-load-spec-failures.md
        main_commit: 95277ed34bbff206dc1f9e85924827f18c001963
    completion:
        token: close-1b284d659565
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 380831d8685885cc9563c832e12af018c73a53f1
        evidence_commit: af826303461c3e8ec4cfc8bd43ca104ba4fcdf41
---

# Heavy specs fail only under parallel make test (document_semantic, perf_document, document_fold_batches)

## Problem
