# Boundary Review — parley.nvim#243 (whole-issue close)

| field | value |
|-------|-------|
| issue | 243 — HTML export: branch topic is inserted unescaped by make_branch_div |
| repo | parley.nvim |
| issue file | workshop/issues/000243-export-branch-topic-unescaped.md |
| boundary | whole-issue close |
| milestone | — |
| window | 45eda77e14d6dd2a2b5422a6ac954b817673b871..eba015a3047130fe96ded4df63664dec59b25309 |
| command | sdlc close --issue 243 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T00:48:51-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Running the exporter specs to confirm the tests pass at head.

I've finished the diff inspection and test runs. Next comes the verdict.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The fix for the branch path is correct and has proper tests. One shared `escape_html` covers `&`, `<`, `>` and `"`. It is used by `make_branch_div` and the new `make_branch_anchor`, in both the HTML and the Markdown export. I ran `make test-spec SPEC=export/tree_export` at head: 13/13 integration and 44/44 unit tests pass. I then put the base version of `lua/parley/exporter.lua` back into the checkout and ran it again. The integration spec failed 1 test (A0) and the unit spec failed 7 (all of Group G2), so the new tests do catch the bug. I restored the file afterwards. Every Done-when item is delivered.

One problem remains, and it is in the same family the issue is about. The chat's own `topic:` header goes into the HTML page's `<title>` without escaping (`lua/parley/exporter.lua:884`). A topic containing `</title><script>` still runs in the exported page. In practice a child chat's topic is usually the same text as its branch topic, so the child's page can still contain the raw script that #243 removes from the nav link. It is a one-line fix with the helper that now exists, which is why the verdict is FIX-THEN-SHIP and not SHIP.

1. **Strengths**
   - `escape_html` (`exporter.lua:331-335`) uses a function for the replacement, which avoids the LuaJIT problem with `%` in replacement strings, and it escapes `"` so it is safe inside attribute values.
   - `make_branch_anchor` replaces two inline anchors that were written out by hand (one per format). All four places that build branch HTML now go through two builders.
   - The G2 tests are table-driven and cover all four cases: nav div and inline link, each with and without a link, in both formats. There is also a separate test for escaping inside the href attribute.
   - A0 is an end-to-end test that checks the written HTML file itself, not just an internal helper.
   - The atlas note in `atlas/export/tree_export.md` explains why the escaping has to happen where the link is built.

2. **Critical findings:** none.

3. **Important findings**
   - `lua/parley/exporter.lua:884`: `<title>]] .. info.title .. [[</title>` puts the chat's header topic (`exporter.lua:75-76`) into the HTML without escaping. **(ARCH-PURPOSE)** The issue's problem statement is "a topic containing `<script>` lands raw in the export". The spec narrowed that to "on the branch path", which leaves out this sibling in the same file. Fix: `escape_html(info.title)`. Move `escape_html` above `write_html_file` if needed; it is already above it at line 331. Then add an A0-style check that a `<script>` topic does not appear raw in the child page.
   - I checked every other place where the export inserts chat text:
     - Branch nav div and inline anchor: fixed.
     - Image alt/src: covered by the body escape plus the `"` escape.
     - Markdown Jekyll title: YAML with `''` quoting, not HTML.
     - Plain-text fallbacks: body text, as the spec says.
     
     `<title>` is the only gap left.

4. **Minor findings**
   - **ARCH-DRY:** `simple_markdown_to_html` still escapes `&`, `<` and `>` with three separate gsubs (`exporter.lua:474-476`), and the image code escapes `"` itself (`:487-488`). Both repeat what `escape_html` does. They could use it, or a version without the quote escape for body text.
   - The markdown href is now `escape_html("{% post_url slug %}")`. If the basename fallback for the slug ever contains `"` or `&`, escaping would break the Liquid tag. The spec says this case was checked and is acceptable.

5. **Test coverage:** The new tests fail without the fix: 7 G2 cases and A0, which I confirmed by putting the base file back. Nothing tests `<title>` escaping, which matches the gap above.

6. **Architecture notes:**
   - **ARCH-DRY:** passes for the new code, which uses one helper and one anchor builder. There is minor leftover duplication in the body escape.
   - **ARCH-PURE:** passes. The builders are pure, and `_process_branch_lines` is tested without IO.
   - **ARCH-PURPOSE:** flagged, for the `<title>` sibling described above.

7. **Plan revision recommendations:** Add a `## Revisions` entry that widens the Spec's class from "on the branch path" to "every HTML string the exporter builds from chat text". It should name the page `<title>` and add a Done-when item for it.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: chat-text-into-built-html-unescaped
    title: |
      HTML export inserts the chat topic into the page title without escaping (exporter.lua:884)
    detail: |
      write_html_file builds `<title>` .. info.title .. `</title>`, where info.title is the chat's raw `topic:` header (exporter.lua:75-76). A topic like `</title><script>alert(1)</script>` lands raw in the exported page, and a child chat's topic usually equals its branch topic, so the script #243 removed from the nav link is still in the child's page. Same class as #243 (ARCH-PURPOSE sweep). Every place the export inserts chat text was checked: branch nav div and inline anchor are fixed; image alt/src are covered by the body escape plus the quote escape; the Markdown Jekyll title is YAML-quoted; the plain-text fallbacks are body text. The title is the only remaining instance. Fix: escape_html(info.title), plus an end-to-end check that a `<script>` topic is not raw in the exported page.
  - id: new
    severity: Minor
    kind: defect
    family: duplicated-html-escape
    title: |
      simple_markdown_to_html repeats escape_html's work with its own gsubs
    detail: |
      exporter.lua:474-476 escapes `&`, `<`, `>` with three separate gsubs, and exporter.lua:487-488 escapes `"` for the image src/alt itself. Both repeat what escape_html (exporter.lua:331-335) now does (ARCH-DRY). Make them use the helper, or a version without the quote escape for body text.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"4f4f5428-2fcf-45f5-a57a-ef1494a9d40a","repository":"github.com/xianxu/parley.nvim","issue_id":"000243","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/a77483556ebaabae","reviewed_head":"eba015a3047130fe96ded4df63664dec59b25309","slot":"parley.nvim:3","requested_at":"2026-10-16T07:47:41.37071Z"},"phase":"finished","pid":55581,"started_at":"2026-10-16T07:47:41.565166Z","finished_at":"2026-10-16T07:48:50.636573Z","session_id":"e58bcf4d-2e93-4cc8-9d42-1173ef77d44c","outcome":"returned"}] -->
