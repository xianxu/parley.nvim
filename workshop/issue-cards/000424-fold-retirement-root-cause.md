---
id: 000424
status: open
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
github_issue:
flake_tests: [lua:tests/integration/document_fold_uncertainty_retirement_spec.lua#native suspended fold retirement restores the operator preference and view when detach interrupts suspended uncertainty]
---

# fold retirement timeout: root cause from captured evidence

## Problem

The native suspended fold-retirement timeout recorded during #410 remains unexplained. #420 lands bounded evidence capture in both retirement fixtures; its controlled fan-out did not reproduce the failure and does not claim a root-cause fix.
