# Artifact-reference navigation (#160)

Jump from a symbolic ariadne artifact ref under the cursor — `ariadne#11`,
`#15 M4`, `pair#84`, `gh#42` — to the current file it names, and highlight refs
so they read as navigable. Refs stay **symbolic** (the id is stable, the path is
not: slugs rename, files move `issues/ → history/` on close/merge); resolution
happens at **read time**, so nothing is stored and nothing rots.

## The single-source contract (why this is thin)

`sdlc resolve` (ariadne#144, base-layer Go) is the **sole authority** for the ref
grammar, cross-repo resolution, family lookup, and archive-correctness. parley
does **not** re-encode any of that — it shells to `sdlc resolve --json` and renders
the result. So parley's whole job is: detect a ref-shaped token, call the binary,
open/pick the result, highlight refs.

- `lua/parley/artifact_ref.lua` — the module.
  - `iter_refs(line)` — a **loose** ref-shape detector (candidate-flagger for
    cursor extraction + highlighting). It is NOT the grammar; an over-match is
    simply rejected by `sdlc resolve` at jump time. Shared by the cursor parser
    and the highlighter so the ref-shape lives once (ARCH-DRY).
  - `parse_ref_at_cursor(line, col)` — the ref span containing the cursor
    (absorbs an interior space, e.g. `#15 M4`, which `<cword>`/`<cfile>` can't).
  - `parse_resolve_output(stdout, is_json)` / `run_resolve(ref, opts, on_done, runner)`
    — parse + shell-out (via `issues.build_spawn_argv`; injected runner → unit-testable).
  - `dispatch_resolve_result` — 0 files (github/external) → notice; 1 → open; N
    (a family) → picker. `goto_ref_at_cursor` is the editor entry.

## Editor surface

- **Highlight:** `ParleyArtifactRef` (underline) painted by the decoration
  provider (`highlighter.lua`, shared `push_artifact_refs` in both the chat and
  markdown compute paths). Override via `config.highlight.artifact_ref`. Marks
  ref-*shaped* tokens (confirming resolvability per-token per-redraw would spawn
  `sdlc` far too often); an unresolvable one just surfaces sdlc's error on jump.
- **Keymap:** `<C-g>r` (`resolve_ref` in the keybinding registry; the `<C-g>`
  chord family, avoids shadowing Vim's native `gf`) → `M.cmd.ResolveRefUnderCursor`,
  bound in both chat and markdown `parley_buffer` scope.
- **Picker:** a family ref (issue + plan + reviews) opens the house `float_picker`;
  a single result opens directly.
- **Cross-repo:** `sdlc resolve` resolves `pair#84` etc. itself; parley only sets
  the child process `cwd` (via `neighborhood.for_buf`) so a bare `#id` anchors to
  the repo that owns the current buffer.

## Configuration

- `config.sdlc_cmd` (default `"sdlc"`) — the resolver command. **Must point at the
  sdlc BINARY**: a shell *function* named `sdlc` is not reachable from `vim.system`.
  If a real `sdlc` binary is on `$PATH`, the default works; otherwise set an
  absolute path (e.g. `~/workspace/ariadne/bin/sdlc`). Read-only ⟹ lock-free + fast.
- `config.chat_shortcut_resolve_ref` — override the `<C-g>r` binding.

## Related

- ariadne#144 — `sdlc resolve`/`open` (the resolver this consumes); its atlas is
  `ariadne/atlas/workflow/sdlc-binary.md` (§ "Artifact-reference resolution").
- [File References (@@)](file_references.md) — the other reference syntax in chat.
