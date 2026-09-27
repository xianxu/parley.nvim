---
id: '000105'
status: punt
created: 2026-04-13
updated: 2026-05-05
---

# Review visual feedback and progress component

## Problem

The review flow (`<C-g>ve` / `<C-g>vr`) sends the whole document to the API and waits — no visual indication of progress. For documents with many markers, this feels unresponsive.

Two parts to this:
