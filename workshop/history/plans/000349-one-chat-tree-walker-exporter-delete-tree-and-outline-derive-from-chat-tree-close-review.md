# Boundary Review — parley.nvim#349 (whole-issue close)

| field | value |
|-------|-------|
| issue | 349 — One chat tree walker: exporter, delete-tree and outline derive from chat_tree |
| repo | parley.nvim |
| issue file | workshop/issues/000349-one-chat-tree-walker-exporter-delete-tree-and-outline-derive-from-chat-tree.md |
| boundary | whole-issue close |
| milestone | — |
| window | 9bf2df8c374ae8665a294bb183dc2478842352c5..4ad18c79c7234acc80db7c525e8a4313a4887e60 |
| command | sdlc close --issue 349 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T08:54:03-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I've read the diff and confirmed that no other module follows `parent_link`. Next I'm checking for leftover tree-root helpers and running the tests.

Running the affected specs directly now.

Affected specs all pass. Last check: whether any other resolve caller is itself walking the tree.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The change does what the issue asks. All five copies of the tree-walking logic are gone. `chat_tree.root` and `chat_tree.files` are now the only place that follows `parent_link` or walks `branches`, which I confirmed by grepping `lua/`: the outline's display rows are the one exemption, and it is documented. I ran the affected specs at the pinned head and all passed: `chat_tree_spec` 17, `exporter_tree_spec` 44, `chat_tree_context_spec` 21, `chat_move_spec` 17, `tree_export_spec` (exit 0), `ancestor_chain_rename_spec` 6, `single_source_sweeps_spec` 27. `chat_finder_logic_spec` did not run, for a reason unrelated to the code: its child process could not load plenary when I set up the isolated environment by hand. One problem should be fixed before shipping, and it is cheap. Delete-tree, move and export now stop 20 levels below the root. The old downward walkers had no depth limit, so this is a second behaviour change. The plan says there is only one, and the change can make a move or delete act on part of a tree without saying so.

Done-when: current. The three clauses (root and files come from `chat_tree`; export, delete-tree and the outline keep their tests green; the sweep guard) still describe this diff. The Revisions only change which loader is used (`disk_deps`) and how a chat with no header loads, so both fit inside those clauses.

**1. Strengths**
- `lua/parley/chat_tree.lua:106-130`: `root` reuses `path_up`, so delete, move, export and `<M-t>` see the same tree as the request context. `files` takes its file reads as a parameter and is unit-tested with hand-built parses (ARCH-PURE: pass).
- `lua/parley/exporter.lua:141-163`: the export's loader keeps a table of what it has already read, so finding the root and walking down still read each file once, as before.
- `tests/integration/chat_tree_context_spec.lua:341-352`: one test checks the deliberate change (a child its parent no longer lists is its own tree) through all three consumers: `get_chat_tree_files`, the outline and the exporter.
- `tests/integration/chat_move_spec.lua:413-423`: the delete-tree test now checks the confirmation text, which closes the gap described in the lessons entry.
- The sweep fails if its pattern stops matching anything in `chat_tree.lua` (`hits >= 3`), so it can't pass by matching nothing.

**2. Critical findings**
None.

**3. Important findings**
- **`lua/parley/chat_tree.lua:121`: `files` stops 20 levels below the root.** The old `init.collect_tree_files` and `exporter.collect_tree` had no depth limit; they only tracked files already visited. Take a chain of 22 nested chats. Delete-tree now deletes 21 files and leaves the deepest one behind. Move relocates 21 and strands the deepest one with a broken parent link. Export leaves it out. Nothing tells the user any of this happened.
  - The plan's "Behaviour change (one, deliberate)" is therefore wrong: there are two.
  - Fix: in `files`, drop the depth check. The `seen` set already stops cycles, so the walk still ends. Alternatively, keep a limit but report a truncated walk to the caller.
  - Every file in this window that applies the limit: `chat_tree.files` here. `path_up` keeps 20 ancestors, about the same as the old upward walkers, so the upward direction does not regress.
  - Add a test: a chain longer than the limit is listed in full by `get_chat_tree_files`.

**4. Minor findings**
- **ARCH-DRY.** The `resolve` wrapper appears three times: `chat_tree.lua` in `io_deps` and in `disk_deps`, and `exporter.lua:143`. The code that finds the header and parses the chat is repeated between `io_deps` and `disk_deps`. A small shared helper would cover both.
- **The sweep only catches one way of writing it.** The regex in `tests/arch/single_source_sweeps_spec.lua` matches `resolve(…parent_link.path` written on one line. Code like `local l = p.parent_link; resolve(l.path, …)` would get past it.
- **Comment in `init.lua:3724-3726`.** It says `chat_tree_files` is "one walker for the request context, delete-tree, move, export and the outline". Only delete-tree, move and `get_chat_tree_files` call that function. The request context, export and outline call `chat_tree` directly.
- **Header comment of `chat_tree.lua:1-8`.** It still describes only the request context, `path_up`/`linearize` and `io_deps`. It doesn't mention `root`, `files` or `disk_deps`.
- **Unit test wording.** The unit test name says "skipping unloadable ones", but `gone.md` has no children. Nothing checks that an unloadable file's subtree is skipped too, as the doc comment says.

**5. Test coverage notes**
`root` has unit tests for a found root, an orphaned child, an unloadable file and following a link chain. `files` has tests for order, cycles, the depth limit and identity of the returned parse. Integration tests cover the three consumers. Missing: a test that a deep chain is listed in full by delete-tree and move, which is the bug class in finding 3.

**6. Architectural notes**
- ARCH-DRY: pass for the walker. All five copies are deleted and every consumer goes through `chat_tree`. Only the small duplication of loaders and resolve wrappers remains (Minor).
- ARCH-PURE: pass. `root` and `files` only touch files through the injected `deps`, and the file-system code sits in the `disk_deps`/`io_deps` loaders.
- ARCH-PURPOSE: pass. I checked every caller of `resolve_chat_path` in `lua/`. The others are one-hop navigation or reference rewriting, not tree walks. The only `parent_link` read outside `chat_tree` is `exporter.lua:374`, which builds a link label.

**7. Plan revision recommendations**
- Add a "## Revisions" entry saying the downward walk now has a depth limit where the old walkers had none, or record that the limit was removed if the fix drops it. "Behaviour change (one, deliberate)" should stop claiming there is only one.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: walker-cap-truncates-tree
    title: |
      chat_tree.files stops 20 levels below the root, so delete-tree, move and export can silently act on part of a tree
    detail: |
      lua/parley/chat_tree.lua:121 returns once depth > MAX_DEPTH (20). The old init.collect_tree_files and exporter.collect_tree had no depth limit and only tracked visited files. In a chain of 22 nested chats, delete-tree leaves the deepest file, move strands it with a broken parent link, and export leaves it out, all without telling the user. This contradicts the plan's claim of a single deliberate behaviour change. The only site in this window is chat_tree.files; path_up keeps about the old upward limit. Fix: drop the depth check in files (the seen set already stops cycles) or report truncation to the caller, and add a test that a chain longer than 20 is listed in full by get_chat_tree_files.
  - id: new
    severity: Minor
    kind: defect
    family: duplicated-deps-loader
    title: |
      The resolve wrapper and the header-parse loader are repeated across io_deps, disk_deps and exporter tree_deps
    detail: |
      The resolve lambda appears in chat_tree.lua io_deps, chat_tree.lua disk_deps and exporter.lua:143. The find_header_end plus parse_chat block is repeated in io_deps and disk_deps (ARCH-DRY).
  - id: new
    severity: Minor
    kind: defect
    family: comment-claim-drift
    title: |
      Comments overstate or omit what chat_tree_files and chat_tree.lua cover
    detail: |
      init.lua:3724-3726 says chat_tree_files is the one walker for the request context, export and the outline, but only delete-tree, move and get_chat_tree_files call it. The header comment at chat_tree.lua:1-8 still covers only path_up, linearize and io_deps, not root, files or disk_deps.
  - id: new
    severity: Minor
    kind: defect
    family: sweep-pattern-coverage
    title: |
      The single-source sweep only catches resolve(...parent_link.path written on one line
    detail: |
      Pulling the link into a local first (local l = p.parent_link; resolve(l.path, d)) gets past the guard in tests/arch/single_source_sweeps_spec.lua.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"05fa9639-26d5-473e-9d40-7bc25b068321","repository":"github.com/xianxu/parley.nvim","issue_id":"000349","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/709234c26a20c6fc","reviewed_head":"4ad18c79c7234acc80db7c525e8a4313a4887e60","slot":"parley.nvim:3","requested_at":"2026-10-16T15:46:46.99939Z"},"phase":"finished","pid":71586,"started_at":"2026-10-16T15:46:47.190334Z","finished_at":"2026-10-16T15:54:03.568498Z","session_id":"4f74fa47-0a0e-442f-9c74-c212fc1056d3","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T09:06:15-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 349 — One chat tree walker: exporter, delete-tree and outline derive from chat_tree |
| repo | parley.nvim |
| issue file | workshop/issues/000349-one-chat-tree-walker-exporter-delete-tree-and-outline-derive-from-chat-tree.md |
| boundary | whole-issue close |
| milestone | — |
| window | 9bf2df8c374ae8665a294bb183dc2478842352c5..5f72682db64c82b47452ac2f7dcbde6a1c85a1ab |
| command | sdlc close --issue 349 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T09:06:15-07:00 |
| verdict | SHIP |

## Review

Diff and plan read; round-1 fixes look present. Now running the test suite and checking the outline/exporter seams.

Running the relevant specs; the summary grep missed the output format, so checking raw output.

The chat_tree tests are mapped under chat/memory; running that suite plus the sweep spec now.

```verdict
verdict: SHIP
confidence: high
```

The round-1 fix holds. There is no depth cap left in `lua/parley/chat_tree.lua`: `path_up` uses `while true` under `seen`, `linearize`'s `subtree` lost its `depth` argument, and `files` walks with an explicit stack under `seen`. Tests pin each change. In `tests/unit/chat_tree_spec.lua`, a 31-file chain is walked up through `path_up`, and down through `files` with a cycle back to the top. In `tests/integration/chat_tree_context_spec.lua`, a 23-file chain on disk is listed in full from its deepest file. The old cap of 20 would break all three: 21 entries instead of 31, or a root two files down. The five old walkers are gone, and every consumer now derives from `chat_tree.root` and `chat_tree.files`. I ran `make test-spec` for `chat/lifecycle`, `export/tree_export`, `ui/outline` and `chat/memory`. No file reported a failure, and in `chat/memory` all 22 `chat_tree_context_spec` tests and all 18 `chat_tree_spec` tests passed. The one new finding is Minor: the issue's Spec and Plan text still says `files` is depth-capped. It does not block the gate.

Done-when: current. The three bullets are delivered. `root` and `files` derive from `chat_tree`, the export, delete-tree, move and outline tests pass, and the sweep exists. The two behaviour changes made in Revisions (an orphaned child is its own root, and there is no depth cap) are covered by tests. Done-when does not need to name them.

1. **Strengths**
   - `lua/parley/chat_tree.lua:149-177`: `root` and `files` are pure over the injected `deps`. They are unit-tested with hand-built parses, including an orphan, an unloadable file, an unloadable file's subtree, a cycle and a long chain (ARCH-PURE).
   - `lua/parley/exporter.lua:259-267`: `tree_deps` caches one info object per file, so finding the root and walking the tree read each file once. The exporter keeps its own loader while the link rules stay in `chat_tree`.
   - `chat_tree.resolve` and the local `parse` are now shared by `io_deps`, `disk_deps` and the exporter, which fixes the BR-2 duplication.
   - `tests/integration/chat_move_spec.lua:543`: delete-tree's test now checks the text of the confirm prompt. It no longer stubs the prompt blind, and `workshop/lessons.md` records why.
   - `tests/arch/single_source_sweeps_spec.lua:498-524`: the sweep checks that its own patterns still match the walker (`hits >= 3`), so it cannot pass against an empty corpus.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - Issue Spec, `## Core concepts`: the `files` row still says "depth-capped". The Plan also still says "under the same depth cap as `linearize`", and its first Step lists "the depth cap" as a unit case. Revisions reverses all three, but the contract text contradicts itself (see the findings block).

5. **Test coverage notes**
   - Each BR-1 change is pinned by a test that would fail with the cap back in.
   - The orphaned-child rule is pinned for all three consumers: `get_chat_tree_files`, `outline._find_tree_root` and `exporter._find_tree_root`.
   - A legacy file without front matter loading as a leaf is covered through the `chat_finder_logic` move cases (per Revisions). No direct `disk_deps` unit case was found. That is acceptable, because `disk_deps` is the IO layer.

6. **Architectural notes**
   - **ARCH-DRY: pass.** There is one resolver and one header parse. The outline's branch-row resolve is exempt by design and the exemption is documented.
   - **ARCH-PURE: pass.** `root` and `files` are pure over `deps`. `disk_deps` and `io_deps` are the thin IO layer.
   - **ARCH-PURPOSE: pass.** All five copies are deleted, and delete-tree, move, `get_chat_tree_files`, export and the outline all derive from `chat_tree`. The outline's render walk is not a file walk.
   - **ARCH-MOCK: pass (N/A).** There is no external binary or service. Chat-file IO is injected through `deps`.
   - **ARCH-CONSTRAINTS: pass.** These are interactive commands on small trees. The walks are bounded by the number of distinct files (`seen`), not by a cap. `linearize` still recurses, but only along real tree depth.
   - **ARCH-SECURE: pass.** Chat files can be hand-edited. Cycles end at `seen`, and a missing or unparseable file is skipped or becomes its own root, never a crash.
   - **ARCH-ORDER: pass.** Nothing is held between events; each command walks the tree afresh.
   - **ARCH-FUNERAL: pass.** Nothing durable is created.

7. **Plan revision recommendations**
   - Fix the contract in place: in the `files` row, replace "depth-capped" with "no depth cap; `seen` ends a cycle". Strike "under the same depth cap as `linearize`" in the Plan, and change "the depth cap" in Step 1 to "a chain deeper than 20".

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      All three caps are gone (path_up, linearize, files); the 31-file chain unit cases and the 23-file get_chat_tree_files integration case fail under a cap of 20; suites pass.
  - id: BR-2
    disposition: addressed
    note: |
      chat_tree.resolve is shared by io_deps, disk_deps and exporter tree_deps; the header parse is one local parse() (chat_tree.lua:180-189).
  - id: BR-3
    disposition: addressed
    note: |
      init chat_tree_files comment names delete-tree, move and get_chat_tree_files; chat_tree.lua header covers root, files, io_deps and disk_deps.
  - id: BR-4
    disposition: withdrawn
    note: |
      The operator accepted this trade-off in Revisions (a per-line allow list would be more fragile); the guard still catches a re-pasted walker in the old one-expression form.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: comment-claim-drift
    title: |
      The Spec and Plan still say chat_tree.files is depth-capped; Revisions removed the cap
    detail: |
      This is the 2nd finding in family comment-claim-drift. Earlier rounds fixed instances in code comments; this one is in the issue contract (the files row of the Core concepts table, the Plan bullet "under the same depth cap as linearize", and Step 1's "the depth cap"). Rule: when a Revisions entry reverses a property, every restatement of that property (Spec table, Plan, Steps, atlas, code comments) is corrected in the same commit, found by grepping for the property's name ("depth cap", "20"). Prevalence: 3 stale sites, all in the issue file; code and atlas are clean.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"3961d485-8305-44f1-abf6-753592fe1185","repository":"github.com/xianxu/parley.nvim","issue_id":"000349","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/6c0e44c40daa9047","reviewed_head":"5f72682db64c82b47452ac2f7dcbde6a1c85a1ab","slot":"parley.nvim:3","requested_at":"2026-10-16T15:59:09.138395Z"},"phase":"finished","pid":53005,"started_at":"2026-10-16T15:59:09.263139Z","finished_at":"2026-10-16T16:06:05.822791Z","session_id":"abd9eb45-9dc5-4297-8250-2f8b6214d727","outcome":"returned"}] -->
