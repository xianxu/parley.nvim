# Boundary Review — parley.nvim#116 (milestone M3)

| field | value |
|-------|-------|
| issue | 116 — datatype-aware navigation and creation via descriptor |
| repo | parley.nvim |
| issue file | workshop/issues/000116-datatype-aware-navigation-and-creation-via-descriptor.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | a37a83236b25ccdfda58bf81fa5d27ad4981d873..HEAD |
| command | sdlc milestone-close --issue 116 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-06-30T12:37:56-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Confirmed the regression. sdlc's `--issues-dir` defaults to the **relative** `"workshop/issues"`, and `dest := filepath.Join(f.IssuesDir, …)` + `os.WriteFile(dest)` writes **relative to sdlc's process cwd** (which `vim.fn.system` inherits from nvim's `getcwd()`). The old `create_issue` anchored creation at the **git root** (`get_issues_dir()` = `git_root .. "/" .. issues_dir`). So when nvim's cwd isn't the repo root, the new path diverges. I have everything I need.

VERDICT: FIX-THEN-SHIP (confidence: high)

The M3 delegation is cleanly executed and the boundary is non-blocking: the pure/IO split is exemplary (a pure `parse_issue_new_output` + a thin `run_sdlc_issue_new` over an injectable runner), the documented sdlc stdout/stderr stream split is accurate (verified against `cmd/sdlc/issue.go`), the parser's "match the bare `.md` token, not a stream position" design is genuinely robust (I confirmed `vim.fn.system` merges stderr in this runtime, so the parser *must* skip the spaced "Created …"/warning lines — and it does), `create_issue` was removed with no orphaned callers, full suite is green (`make test` exit 0, lint 0/0/237, issues_spec OK). The one thing to fix before `sdlc close`: `cmd_issue_new` now anchors issue creation at nvim's **cwd** instead of the **git root**, a silent regression of the #142 location contract when cwd ≠ repo root.

## 1. Strengths

- **ARCH-PURE textbook split.** `parse_issue_new_output` (`issues.lua:342`) is pure and tested IO-free; `run_sdlc_issue_new` (`issues.lua:359`) is thin IO over it with a default-vs-injectable runner so tests never invoke real sdlc (`issues_spec.lua:84-117`). This is exactly the pure-core/thin-shell shape the plan promised.
- **Robust, well-reasoned parser.** Matching `^%S+%.md$` (the one space-free token) rather than "last line" is the right call — I verified empirically that `vim.fn.system` *merges* stderr here, so the "Created …" + sync-warning lines really do land in the captured output, and the parser correctly skips them regardless of pipe interleaving. The test at `issues_spec.lua:63-68` pins exactly this merged-stream case.
- **Faithful delegation contract.** The stdout=bare-path / stderr=Created+warnings claim in the code comment (`issues.lua:337-341`) matches `cmd/sdlc/issue.go` verbatim (`fmt.Fprintln(stdout, dest)` vs `cok(stderr, …)`/`cwarn(stderr, …)`).
- **Clean removal.** `create_issue` deleted with zero remaining call sites; `render_issue_template`/`ISSUE_TEMPLATE`/`next_issue_id` correctly retained (still used by `cmd_issue_decompose`) and the retention is documented with rationale (`issues.lua:589-596`).

## 2. Critical findings

None.

## 3. Important findings

**I1 — Issue creation now anchors at nvim's cwd, not the git root (regresses the #142 location contract). `issues.lua:674`, `:361` (ARCH-DRY / ARCH-PURPOSE)**

`run_sdlc_issue_new` builds `{"sdlc","issue","new",title}` with no `--issues-dir`, so sdlc uses its relative default `"workshop/issues"` and writes `filepath.Join("workshop/issues", …)` **relative to its process cwd** = nvim's `getcwd()` (`cmd/sdlc/issue.go:217,265,288`). The deleted `create_issue` resolved via `get_issues_dir()` = `git_root .. "/" .. issues_dir` (`issues.lua:391-410`), i.e. git-root-anchored and cwd-independent.

Failure scenario: nvim launched (or `autochdir`'d) in a subdir like `lua/parley/`. `:ParleyIssueNew` → sdlc creates a stray `lua/parley/workshop/issues/000001-foo.md` (and `NextID` scans that empty dir → **allocates a colliding ID**, e.g. `000001`), then parley's `fnamemodify(path, ":p")` (relative to the same cwd) opens that stray file. The #142 prompt label still shows the *git-root* repo basename via `get_issues_repo_root()` — so the label now lies about where the file lands. Common case (cwd = repo root) is unaffected; no crash or data loss, hence Important not Critical, but it silently misfiles + can collide IDs.

Fix sketch (root cause): pass the already-resolved absolute dir so creation routes through the same resolution every other reader uses (ARCH-DRY) — `cmd_issue_new` computes `M.get_issues_dir()` and forwards it as `opts.issues_dir`; `run_sdlc_issue_new` appends `--issues-dir <abs>`. sdlc then prints an absolute `dest`, making the subsequent `:p` a no-op and the open/create locations identical and cwd-independent. Verify the #82 broadcast-to-main still behaves with an absolute issues-dir.

## 4. Minor findings

- **Leading-dash titles are parsed as flags.** A title like `"-n: refactor"` becomes a bare argv element starting with `-`; cobra/pflag treats it as a flag → spurious failure (the old non-shell path was immune). Cheap guard: append `"--"` before `title` in the argv (`issues.lua:361`). Combine with the I1 fix.
- **`--deps`/`--slug` plumbing has no production caller.** `cmd_issue_new` calls `run_sdlc_issue_new(title)` with no opts, and the child-decompose flow was *not* migrated (took the documented M3.4 fallback), so `opts.deps`/`opts.slug` (`issues.lua:362-369`) are exercised only by tests. Mild speculative generality — acceptable as the documented forward API for the eventual child migration, but note it ships unused.
- **`render_issue_template` retention vs the `## Plan` text.** The issue's M3 checkbox (`000116…md:95`) and plan (`plan.md:314`) say "retire `render_issue_template`", but it's retained for the child flow. The Log entry documents the partial retirement; the Plan line itself reads as fuller than reality (see §7).

## 5. Test coverage notes

- Pure parser + runner seam are well covered, including the merged-stream case and the three error branches (non-zero exit, unparseable output, success). Good — this covers the bug class the *parser* could ship.
- **Gap:** the real IO integration (`cmd_issue_new` → actual `vim.fn.system` → cwd-relative resolution → `:p` open) is entirely faked, which is exactly why I1 (cwd anchoring + ID collision from a subdir) is untested and ships silently. A small integration test that runs `run_sdlc_issue_new` with a real fake-`sdlc` script on `$PATH` from a subdir cwd, asserting the created path resolves under the git root, would pin the fix. Not blocking, but it's the test that would have caught I1.

## 6. Architectural notes for upcoming work

- **ARCH-DRY: PASS, with tracked debt.** `cmd_issue_new` now single-sources to sdlc; the remaining `render_issue_template` for the child flow is documented and tracked (ariadne#145). Note the *new* DRY seam I1 exposes: issue-dir resolution now has two implementations — parley's `get_issues_dir()` (git-root) and sdlc's cwd-relative default — and the fix (forward `--issues-dir`) collapses them back to one.
- **ARCH-PURE: PASS.** Exemplary; nothing to add.
- **ARCH-PURPOSE: mostly PASS.** Shadow-sweep of issue-creation consumers: `cmd_issue_new` derives from sdlc ✓; `cmd_issue_decompose` still hand-maintains `ISSUE_TEMPLATE` ✗ (documented deferral, tracked). The deferred child flow is a genuine secondary path, not the cheap-win evasion the principle targets — acceptable. The I1 cwd-anchoring does nick the purpose ("delegate to the canonical creator" should mean issues land in the canonical location); fixing it completes the intent.

## 7. Plan revision recommendations

- **Issue file (`000116…md`), `## Revisions`:** add an entry noting M3 took the M3.4 **fallback** — `render_issue_template`/`ISSUE_TEMPLATE`/`next_issue_id` are *retained* for `cmd_issue_decompose`; only the top-level `cmd_issue_new`/`create_issue` path was retired. The M3 `## Plan` checkbox text ("retire … `render_issue_template`") otherwise overstates the delivered scope. (The Log already records this; the Plan line should be reconciled so the plan stops claiming full retirement.)
- **Plan (`000116-discovery-registry-plan.md`), M3.3:** the task says only `:edit` the returned path; it omits the cwd-vs-git-root resolution decision that I1 surfaces. If I1 is fixed by forwarding `--issues-dir <abs>`, add a one-line note to M3.3 recording that creation is anchored at `get_issues_dir()` (git root), not sdlc's cwd default — so the contract is explicit rather than incidental.
