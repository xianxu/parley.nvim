// pr.go — `sdlc pr` subcommand. Ports the `pull-request:` Make target.
//
// Run from a worktree branch (refuses main). Pushes the branch with
// upstream tracking, scans touched issue files since branch point for
// github_issue: frontmatter, formats them as "Fixes #1, #2, #3", and
// opens a PR via `gh pr create`. Mirrors Makefile.workflow ~lines 350-388.
package main

import (
	"fmt"
	"io"
	"os"
	"sort"
	"strconv"
	"strings"

	"github.com/spf13/cobra"

	"github.com/xianxu/ariadne/cmd/sdlc/internal/gitx"
	"github.com/xianxu/ariadne/cmd/sdlc/internal/issue"
)

// prFlags holds the parsed flag values for the pr subcommand.
type prFlags struct {
	DryRun    bool
	IssuesDir string
}

// prRunner is the package-level runner for pr (test seam). Type lives
// in runner.go.
var prRunner gitRunner = execGitRunner{}

// NewPRCmd returns the cobra command for `sdlc pr`.
func NewPRCmd() *cobra.Command {
	f := prFlags{}
	cmd := &cobra.Command{
		Use:           "pr",
		Short:         "Open a PR for the current worktree branch (scans touched issues for fixes)",
		Long:          "Placeholder — replaced by helptext.MustGet(\"pr\") in main.go.",
		Args:          cobra.NoArgs,
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runPR(cmd.OutOrStdout(), cmd.ErrOrStderr(), &f)
		},
	}
	cmd.Flags().BoolVar(&f.DryRun, "dry-run", false, "print would-be PR body + gh command; do not push or create PR")
	cmd.Flags().StringVar(&f.IssuesDir, "issues-dir", envOr("WF_ISSUES_DIR", "workshop/issues"), "directory holding issue files")
	return cmd
}

// runPR dispatches the pr workflow.
func runPR(stdout, stderr io.Writer, f *prFlags) error {
	// ── 1. Refuse if on main / detached ─────────────────────────────────────
	branch := gitx.Capture("branch", "--show-current")
	if branch == "" || branch == "main" {
		die(stderr, fmt.Sprintf("sdlc pr must be run from a worktree branch (current: %s)", valueOr(branch, "(detached)")))
	}

	repo, err := detectRepo()
	if err != nil {
		die(stderr, err.Error())
	}

	// ── 2. Compute merge base ───────────────────────────────────────────────
	base := gitx.Capture("merge-base", "main", "HEAD")
	if base == "" {
		base = "main"
	}

	// ── 3. Collect touched issues + github_issue numbers ────────────────────
	touched, err := touchedIssueFiles(base, f.IssuesDir, prRunner)
	if err != nil {
		die(stderr, fmt.Sprintf("scan touched issues: %v", err))
	}
	ghNums := collectGitHubIssueNumbers(touched)

	// ── 4. Build commits + fixes body ───────────────────────────────────────
	commits := gitCommitsSince(base, prRunner)
	fixes := formatFixes(ghNums)
	body := combineBody(commits, fixes)

	// ── 5. Push branch with upstream ────────────────────────────────────────
	if f.DryRun {
		cinfo(stderr, "dry-run — no push or PR creation")
		fmt.Fprintf(stdout, "Would: git push -u origin %s\n", branch)
		fmt.Fprintf(stdout, "Would: gh pr create --repo %s --base main --head %s\n", repo, branch)
		if fixes != "" {
			fmt.Fprintln(stdout, "── fixes line ──")
			fmt.Fprintln(stdout, fixes)
		}
		if body != "" {
			fmt.Fprintln(stdout, "── PR body ──")
			fmt.Fprintln(stdout, body)
		}
		return nil
	}

	cinfo(stderr, fmt.Sprintf("Pushing %s with upstream tracking...", branch))
	if out, gerr := prRunner.Git("push", "-u", "origin", branch); gerr != nil {
		die(stderr, fmt.Sprintf("git push -u origin %s: %v\n%s", branch, gerr, out))
	}

	// ── 6. Open PR ──────────────────────────────────────────────────────────
	if fixes != "" {
		cinfo(stderr, fmt.Sprintf("Including in PR body: %s", fixes))
	}
	cinfo(stderr, fmt.Sprintf("Creating PR (base=main head=%s)...", branch))
	url, err := ghClient.PRCreate(repo, "main", branch, body)
	if err != nil {
		die(stderr, err.Error())
	}
	if url != "" {
		fmt.Fprintln(stdout, url)
	}
	cok(stderr, "PR created.")
	return nil
}

// ── helpers ──────────────────────────────────────────────────────────────────

// touchedIssueFiles returns workshop/issues/*.md paths changed since
// baseRef. Empty slice if none. Used by pr.go to find linkable issues.
func touchedIssueFiles(baseRef, issuesDir string, r gitRunner) ([]string, error) {
	out, err := r.Git("diff", "--name-only", baseRef+"..HEAD", "--", issuesDir+"/*.md")
	if err != nil {
		return nil, fmt.Errorf("git diff: %v\n%s", err, out)
	}
	return splitNonEmptyLines(string(out)), nil
}

// collectGitHubIssueNumbers reads each path's frontmatter and pulls the
// `github_issue:` value if present + non-empty. Returns unique numbers
// in ascending numeric order (matches the shell's `sort -u`).
//
// Missing files are skipped silently — the shell target uses `[ -f ]`.
func collectGitHubIssueNumbers(paths []string) []string {
	seen := map[string]struct{}{}
	for _, p := range paths {
		data, err := readFile(p)
		if err != nil {
			continue
		}
		fm, _, perr := issue.Parse(string(data))
		if perr != nil {
			continue
		}
		num, ok := issue.GetField(fm, "github_issue")
		if !ok || num == "" {
			continue
		}
		seen[num] = struct{}{}
	}
	var out []string
	for k := range seen {
		out = append(out, k)
	}
	sort.Slice(out, func(i, j int) bool {
		ai, _ := strconv.Atoi(out[i])
		aj, _ := strconv.Atoi(out[j])
		if ai == aj {
			return out[i] < out[j]
		}
		return ai < aj
	})
	return out
}

// formatFixes returns the "Fixes #1, #2, #3" line for the given GitHub
// issue numbers. Returns "" if numbers is empty (matches the shell's
// empty `$fixes` branch which falls through to `gh pr create --fill`).
func formatFixes(numbers []string) string {
	if len(numbers) == 0 {
		return ""
	}
	hashed := make([]string, len(numbers))
	for i, n := range numbers {
		hashed[i] = "#" + n
	}
	return "Fixes " + strings.Join(hashed, ", ")
}

// gitCommitsSince returns "- <subject>\n- <subject>" lines for every
// commit in `main..HEAD`. Empty if none. Mirrors the shell target's
// `git log main..HEAD --pretty=format:'- %s'`.
func gitCommitsSince(_ string, r gitRunner) string {
	out, err := r.Git("log", "main..HEAD", "--pretty=format:- %s")
	if err != nil {
		return ""
	}
	return strings.TrimRight(string(out), "\n")
}

// combineBody assembles the final PR body from the commits list + the
// fixes line. Matches the shell pull-request target's logic:
//
//	if both → "<commits>\n\n<fixes>"
//	if only commits → "<commits>"
//	if only fixes → "<fixes>"
//	if neither → ""
func combineBody(commits, fixes string) string {
	commits = strings.TrimSpace(commits)
	fixes = strings.TrimSpace(fixes)
	switch {
	case commits != "" && fixes != "":
		return commits + "\n\n" + fixes
	case commits != "":
		return commits
	case fixes != "":
		return fixes
	}
	return ""
}

// readFile is a small indirection so tests can stub the file-read path.
// Production reads from disk directly; tests substitute fixtures.
var readFile = os.ReadFile
