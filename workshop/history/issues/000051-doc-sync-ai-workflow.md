---
id: 000051
status: done
deps: []
created: 2026-04-02
updated: 2026-04-02
---

# doc sync for ai workflow scripts

Review workflow-related documentation against the current pre-merge and constitution-check script changes, then update only stale docs.

## Done when

- `specs/` and `README.md` are checked against the current workflow-script diff
- Any stale workflow docs are updated minimally
- Findings are recorded in the log

## Plan

- [x] Inspect the worktree diff and identify changed workflow behavior
- [x] Compare those behaviors against `specs/` and `README.md`
- [x] Update only the stale documentation
- [x] Verify the documentation diff matches the script changes

## Log

### 2026-04-02

- Reviewed `.gitignore`, `scripts/parallel-checks.sh`, and `scripts/pre-merge-checks.sh`
- Found one stale spec detail in `specs/infra/workflow.md`: the constitution hook text was still Claude-specific and did not mention the repo-root state file or Codex default
- Updated `specs/infra/workflow.md` to document the `codex` default, `AGENT_CMD` override, and repo-root `.constitution-check-state`
- Verified the resulting doc diff only changes `specs/infra/workflow.md`; `README.md` remains in sync with this script diff
