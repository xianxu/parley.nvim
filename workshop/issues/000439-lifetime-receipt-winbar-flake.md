---
id: 000439
status: open
deps: []
github_issue:
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
card_mirror: '73954e33728f52c9626dc6be55862338131adbe7' # card fields mirrored from issue-cards; edit via sdlc
---

# Native acknowledgement receipt winbar wait flakes under suite load

## Problem

One native acknowledgement/submit-receipt case failed under integration-suite load while landing #425. The exact integrated head subsequently passed ten matched original-file repetitions, as did its pinned main parent. The hub classifies this as a load-sensitive flake not attributable to #425; its underlying mechanism remains unproven.

## Spec

Investigate tests/integration/agentic_document_lifetime_spec.lua, exact case agentic document buffer lifetime keeps the owned native acknowledgement attached and preserves its submit receipt. Its wait at209 expected the winbar to contain nothing to submit after an owned rename/reload and a second unchanged submit; it timed out. Preserve receipt identity, the one-send assertion, buffer attachment, and window feedback assertions; diagnose the actual state on recurrence rather than raising a timeout.

Flake identity: lua:tests/integration/agentic_document_lifetime_spec.lua#agentic document buffer lifetime keeps the owned native acknowledgement attached and preserves its submit receipt

Failed recorded suite attempt643f6053fb127f96cb0040072983581b on integrated d7d8f4a636b90f1171f98d5a4cc540d5b1242c87 (one failed file,9/1/0 in that file, clean process census). Raw log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/643f6053fb127f96cb0040072983581b.log, SHA256c8e033c30a3fc4b3110b7979f905184328a67c77ddf783498aefc7dd5bb79bad. Total suite3m29s; original case-time load/stage evidence was not captured. This was classified unattributable-failure by the pre-#415 producer; no typed exact-head pass record is fabricated.

Pinned main b31fd0390b69c6b4d8030f670ab2903922dd8ec1 passed this lifetime file in its full diagnostic baseline; that baseline failed a separate bridge test, tracked by #438. Hub explicitly required a matched comparison because #425 changes winbar behavior.

Approved comparison retained the complete original ten-case file and all assertions, with two workers maximum and ten serial repetitions per head through make -k/test-spec and the normal supervisor. Candidate d7d8f4a636b90f1171f98d5a4cc540d5b1242c87: target10/10, aggregate100/0/0. Pinned main b31fd0390b69c6b4d8030f670ab2903922dd8ec1: target10/10, aggregate100/0/0. All20 censuses clean. File durations8.0–18.3s, observed1m load29.1089–54.3755; load samples were taken at each repetition start, not at the historic failing moment. Preferred harness runtime, no synthetic machine stress or request/arrival changes.

Evidence root /Volumes/TestScratch/parley425-compare.QCFLGE: candidate-summary.json SHA256a5b86402cc21c12c7ec296930320deb543061455918e48b975543becdb2f2eb1 and baseline-summary.json SHA25655d1bd6805f3c0f351295b41d58a00629ed3d8fe7b85df38476d90c975faa2bf index the20 logs, each SHA256, exit code, elapsed time, per-rep load, target outcome and census. Summaries are bounded diagnostic scratch and may expire; the numeric results above are the durable record. Exact-code targeted passes are external evidence, not typed recorded-suite pass evidence.

## Done when

- Capture the failed wait's actual receipt, attachment, send count, winbar ownership/feedback, and timing state, and identify the ordering or cost mechanism.
- A deterministic regression and negative control preserve the intended native acknowledgement, deduplication and feedback behavior.
- Fix the owning product or fixture mechanism, pass the relevant tests and recorded gate, and only then retire the registration.

## Plan

- [ ]

## Log

Filed unclaimed at hub direction e2c91634-0979-45a2-b22f-fa6ef63b1d86. Hub classification: one failure under load followed by10/10 target passes on each exact head is sufficient load-sensitive flake evidence not attributable to #425. This is a landing classification, not an identified root cause. No guessed product guard, weakened feedback assertion or deadline increase included.
