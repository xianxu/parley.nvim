# Boundary Review — parley.nvim#352 (whole-issue close)

| field | value |
|-------|-------|
| issue | 352 — Send side chats off the path to the root as their summary lines |
| repo | parley.nvim |
| issue file | workshop/issues/000352-send-side-chats-off-the-path-to-the-root-as-their-summary-lines.md |
| boundary | whole-issue close |
| milestone | — |
| window | add53f6fde4e02f8238851509683e7e35a5831fd..026091672266024816e0fbdd7c03fdb8b055f891 |
| command | sdlc close --issue 352 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T08:23:17-07:00 |
| verdict | SHIP |

## Review

Diff and issue read. Now running the touched specs to confirm they pass.

Tests need the harness environment; running the chat/memory and chat/lifecycle spec sets through `make test-spec`.

```verdict
verdict: SHIP
confidence: high
```

The change delivers #352 as specified. `chat_tree.linearize` marks every item it emits from a subtree as `off_path` (`lua/parley/chat_tree.lua:72,80-81`). A single predicate, `side_chats_summarized`, controls both `build_messages` and `resolve_remote_references`, so the message build and the fetch step cannot disagree. Off-path items are left out of the window count through `rank`, and `side_chat_messages` renders them as the summary pair, or as the truncated, marked question when there is no summary (the TL's revision). Every `## Done when` clause has a test: an aside and a nested aside seen from a later root question, the nested aside's own view (whole path in full), an on-path ancestor kept in full, `"full"` mode, no summary (with multibyte truncation), an off-path `@@` that is neither fetched nor inlined, and the window counting only path exchanges. The atlas pages `memory.md` and `lifecycle.md` and the `config.lua` comment describe the flag and its default. I ran `make test-spec SPEC=chat/memory` and `SPEC=chat/lifecycle` in the harness environment: every mapped file passed, including `chat_tree_context_spec` (18), `chat_tree_spec` (12), `build_messages_spec` (104) and `chat_respond_spec` (53). Nothing blocks shipping; the four findings below are all Minor.

1. **Strengths**
   - Being off-path is recorded once, during the walk (`chat_tree.lua:72`), and has a pure unit test that covers asides off an ancestor before the branch, nested asides, and an aside off the current file (`tests/unit/chat_tree_spec.lua:96-108`).
   - Both builders read one predicate (`chat_respond.lua:346`), so a reference that won't be sent is never fetched (`chat_respond.lua:1327`). The integration test checks this by counting fetches.
   - `rank` passes the window positions of path exchanges only into the unchanged `preserve_exchange` helper (`chat_respond.lua:862-869, 895`). This is a small, correct remap, and the window test pins it.
   - The no-summary path truncates by characters (`strchars`/`strcharpart`), and the test feeds it 400 `é` characters.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - **Duplicated summary rendering (ARCH-DRY).** `side_chat_messages` (`chat_respond.lua:363-367`) repeats the summarized branch's placeholder and summary messages (`:980-983`, `:1027`) instead of sending off-path items through that branch, which is what the plan said would happen. Two near-identical lines exist at two sites.
   - **Plan claims don't match the code.** The checked step says "the README config docs", but `README.md` is not in the diff and has no `chat_memory` section, so the claim is wrong (the `config.lua` comment does satisfy Done-when). The plan also says the no-summary note keeps "the roles still alternate". The code adds the assistant note only when there is an answer, so an unanswered off-path question (A3 in the test) is followed directly by the next user turn. `"full"` mode already behaved this way.
   - **Invalid flag values are silently accepted.** `side_chats_summarized` treats any value other than `"full"` as `"summary"`, so a typo like `"Full"` falls back to the default without a warning.
   - **Asymmetry between the two renderers.** For a summarized off-path item, `side_chat_messages` sends the placeholder even when the question text is blank, while the on-path summarized branch checks for non-whitespace text first.

5. **Test coverage notes:** Both states of every Done-when clause are covered. `"full"` mode is tested only with memory disabled; there is no test of `"full"` with memory enabled, but that path is the same as #233's existing window path. The Log describes mutation checks, which I did not re-run; the existing assertions do target the mutated behaviours.

6. **Architectural notes**
   - ARCH-DRY: flagged as Minor (finding 1).
   - ARCH-PURE: passes. The off-path fact is pure and unit-tested, and the IO-side skip reads the shared predicate.
   - ARCH-PURPOSE: passes. Both consumers that send or fetch exchanges (`build_messages` and `resolve_remote_references`) derive from the predicate. Leaving `build_messages_from_model` out is explicitly declared and justified: it has no production caller and sees no tree.

7. **Plan revision recommendations**
   - Add a `## Revisions` entry: the docs step was satisfied by atlas plus the `config.lua` comment; the README has no config section, so it was not touched.
   - Add a `## Revisions` entry: the "answer omitted" assistant note is sent only when the off-path exchange has an answer.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: duplicated-render-path
    title: |
      side_chat_messages restates the summarized branch's placeholder+summary pair
    detail: |
      chat_respond.lua:363-367 duplicates the summary pair the summarized branch emits at :980-983 and :1027 (strip_definition_footnote_footer of the summary content). The plan promised that off-path items go through the existing summarized branch; a shared helper would give one source. Instances: those two sites only.
  - id: new
    severity: Minor
    kind: defect
    family: plan-claim-unbacked
    title: |
      Plan claims a README config-docs update and role alternation that the code does not deliver
    detail: |
      The checked step says the README config docs were updated, but README.md is not in the diff and has no chat_memory section. The plan's no-summary rule says an assistant note keeps the roles alternating, but chat_respond.lua:376-378 adds it only when there is an answer (the unanswered A3 is followed directly by R2). Record both in Revisions.
  - id: new
    severity: Minor
    kind: defect
    family: config-value-unvalidated
    title: |
      chat_memory.side_chats silently treats any value other than "full" as "summary"
    detail: |
      side_chats_summarized (chat_respond.lua:346-349) has no warning for an unknown value, so a typo such as "Full" falls back to the default without notice.
  - id: new
    severity: Minor
    kind: defect
    family: blank-question-guard
    title: |
      Off-path summary path sends the placeholder even when the question text is blank
    detail: |
      The on-path summarized branch sends the placeholder only when question_content has non-whitespace text; side_chat_messages with a summary sends it unconditionally (chat_respond.lua:363). Only that one site has the difference.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d5839a4e-4c6b-4f22-8153-508b7fc8d963","repository":"github.com/xianxu/parley.nvim","issue_id":"000352","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/3a8b037172fa4dd1","reviewed_head":"026091672266024816e0fbdd7c03fdb8b055f891","slot":"parley.nvim:3","requested_at":"2026-10-16T15:20:16.215553Z"},"phase":"finished","pid":67740,"started_at":"2026-10-16T15:20:16.342231Z","finished_at":"2026-10-16T15:23:16.65554Z","session_id":"86614bd4-3900-4b90-b552-e914a60d406e","outcome":"returned"}] -->
