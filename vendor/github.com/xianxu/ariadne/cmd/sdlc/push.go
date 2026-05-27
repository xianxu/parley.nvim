// push.go — `sdlc push` subcommand. Ports the `push:` Make target.
//
// The direct-on-main ship workflow. Run from main, refuses anything else.
// Sequence (Makefile.workflow ~lines 281-348):
//
//   1. branch == main check
//   2. untracked-files refusal
//   3. auto-commit tracked changes (commit subject synthesized from
//      touched workshop/issues/*.md titles, fallback "auto-commit
//      before push")
//   4. pre-merge judges (plan + specs + lessons by default — same
//      categories the shell `make pre-merge` runs via parallel-checks.sh).
//      Skippable with --no-judge.
//   5. not-done issue warn: scan touched issue files vs origin/main, warn
//      if any are still in working/open/blocked. Skippable with --yes.
//   6. git push
//   7. archive done/wontfix/punt issue files into history/. For status=done
//      with a github_issue: frontmatter, close the GitHub issue first.
//      Commit + push if any moved.
package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/spf13/cobra"

	"github.com/xianxu/ariadne/cmd/sdlc/internal/gitx"
	"github.com/xianxu/ariadne/cmd/sdlc/internal/issue"
	"github.com/xianxu/ariadne/cmd/sdlc/internal/judge"
)

// pushFlags holds the parsed flag values for the push subcommand.
type pushFlags struct {
	Yes        bool
	NoJudge    bool
	DryRun     bool
	IssuesDir  string
	HistoryDir string
}

// pushRunner is the package-level runner for push (test seam). Type lives
// in runner.go.
var pushRunner gitRunner = execGitRunner{}

// NewPushCmd returns the cobra command for `sdlc push`.
func NewPushCmd() *cobra.Command {
	f := pushFlags{}
	cmd := &cobra.Command{
		Use:           "push",
		Short:         "Ship from main: auto-commit, run pre-merge judges, push, archive done issues",
		Long:          "Placeholder — replaced by helptext.MustGet(\"push\") in main.go.",
		Args:          cobra.NoArgs,
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runPush(cmd.OutOrStdout(), cmd.ErrOrStderr(), &f)
		},
	}
	cmd.Flags().BoolVar(&f.Yes, "yes", false, "skip the not-done-issue warn prompt")
	cmd.Flags().BoolVar(&f.NoJudge, "no-judge", false, "skip pre-merge judges (emergency-only)")
	cmd.Flags().BoolVar(&f.DryRun, "dry-run", false, "print would-be operations; do not commit/push/archive")
	cmd.Flags().StringVar(&f.IssuesDir, "issues-dir", envOr("WF_ISSUES_DIR", "workshop/issues"), "directory holding issue files")
	cmd.Flags().StringVar(&f.HistoryDir, "history-dir", envOr("WF_HISTORY_DIR", "workshop/history"), "directory for archived issues")
	return cmd
}

// runPush dispatches the push workflow. Hard guard failures call die()
// directly (red prefix + os.Exit). Soft errors return through cobra.
func runPush(stdout, stderr io.Writer, f *pushFlags) error {
	// ── 1. Branch == main ───────────────────────────────────────────────────
	branch := gitx.Capture("branch", "--show-current")
	if branch != "main" {
		die(stderr, fmt.Sprintf("sdlc push must be run from main (current branch: %s)", valueOr(branch, "(detached)")))
	}

	// ── 2. No untracked files ───────────────────────────────────────────────
	untrackedOut, err := pushRunner.Git("ls-files", "--others", "--exclude-standard")
	if err != nil {
		die(stderr, fmt.Sprintf("git ls-files: %v\n%s", err, untrackedOut))
	}
	untracked := splitNonEmptyLines(string(untrackedOut))
	if len(untracked) > 0 {
		fmt.Fprintf(stderr, "  %s[x]%s Untracked files found — add or .gitignore them first\n", ansiRed, ansiReset)
		for _, u := range untracked {
			fmt.Fprintf(stderr, "       %s\n", u)
		}
		os.Exit(1)
	}

	// ── 3. Auto-commit tracked changes ──────────────────────────────────────
	dirty := gitx.Capture("status", "--porcelain")
	if dirty != "" {
		msg := buildPushCommitMessage(f.IssuesDir, pushRunner)
		cinfo(stderr, "Auto-committing tracked changes...")
		if f.DryRun {
			fmt.Fprintf(stdout, "Would: git commit -a -m %q\n", msg)
		} else {
			if out, gerr := pushRunner.Git("commit", "-a", "-m", msg); gerr != nil {
				die(stderr, fmt.Sprintf("git commit failed: %v\n%s", gerr, out))
			}
		}
	}

	// ── 4. Pre-merge judges ─────────────────────────────────────────────────
	if !f.NoJudge {
		preOpts := preflightOptions{
			Categories: []judge.Category{judge.Plan, judge.Specs, judge.Lessons},
			IssuesDir:  f.IssuesDir,
			HistoryDir: f.HistoryDir,
			DryRun:     f.DryRun,
			Stdout:     stdout,
			Stderr:     stderr,
		}
		if err := runPreflightJudges(preOpts); err != nil {
			die(stderr, fmt.Sprintf("pre-merge judges failed: %v", err))
		}
	} else {
		cwarn(stderr, "--no-judge: skipping pre-merge judges")
	}

	// ── 5. Not-done issue warn ──────────────────────────────────────────────
	notDone, err := touchedIssuesNotDone("origin/main", f.IssuesDir, pushRunner)
	if err != nil {
		cwarn(stderr, fmt.Sprintf("not-done scan skipped: %v", err))
	}
	if len(notDone) > 0 && !f.Yes && !f.DryRun {
		fmt.Fprintf(stderr, "  %s[!]%s Touched issue files that are NOT done:\n", ansiYellow, ansiReset)
		for _, p := range notDone {
			fmt.Fprintf(stderr, "       %s\n", p)
		}
		fmt.Fprintf(stderr, "Continue anyway? [y/N] ")
		var answer string
		_, _ = fmt.Fscanln(os.Stdin, &answer)
		if answer != "y" && answer != "Y" {
			die(stderr, "aborted by operator")
		}
	} else if len(notDone) > 0 && f.Yes {
		cwarn(stderr, fmt.Sprintf("--yes: continuing past %d not-done issue(s)", len(notDone)))
	}

	// ── 6. git push ─────────────────────────────────────────────────────────
	if f.DryRun {
		cinfo(stderr, "dry-run — skipping git push + archive")
		return nil
	}
	cinfo(stderr, "Pushing to origin/main...")
	if out, gerr := pushRunner.Git("push"); gerr != nil {
		die(stderr, fmt.Sprintf("git push failed: %v\n%s", gerr, out))
	}

	// ── 7. Archive done/wontfix/punt issues ─────────────────────────────────
	repo, repoErr := detectRepo()
	if repoErr != nil {
		// Archive can still proceed; we just can't close GitHub issues.
		cwarn(stderr, fmt.Sprintf("repo detection failed: %v (skipping GitHub issue closes)", repoErr))
		repo = ""
	}
	moved, err := archiveDoneIssues(stderr, repo, f.IssuesDir, f.HistoryDir)
	if err != nil {
		die(stderr, err.Error())
	}
	if moved > 0 {
		cinfo(stderr, "Committing archived history...")
		if out, gerr := pushRunner.Git("add", f.IssuesDir+"/", f.HistoryDir+"/"); gerr != nil {
			die(stderr, fmt.Sprintf("git add archive dirs: %v\n%s", gerr, out))
		}
		if out, gerr := pushRunner.Git("commit", "-m", "archive completed issues to history"); gerr != nil {
			die(stderr, fmt.Sprintf("commit archive failed: %v\n%s", gerr, out))
		}
		if out, gerr := pushRunner.Git("push"); gerr != nil {
			die(stderr, fmt.Sprintf("push archive failed: %v\n%s", gerr, out))
		}
		cok(stderr, fmt.Sprintf("archived %d issue file(s) to %s/", moved, f.HistoryDir))
	}

	cok(stderr, "Done.")
	return nil
}

// ── helpers ──────────────────────────────────────────────────────────────────

// buildPushCommitMessage synthesizes a commit message by extracting the
// `# Title` of every workshop/issues/NNNNNN-*.md that has unstaged or
// staged changes. Falls back to "auto-commit before push" if none found
// (matches the shell target's else branch).
//
// Multiple touched issues → newline-joined titles. Single → just the title.
func buildPushCommitMessage(issuesDir string, r gitRunner) string {
	matches, _ := filepath.Glob(filepath.Join(issuesDir, "[0-9][0-9][0-9][0-9][0-9][0-9]-*.md"))
	sort.Strings(matches)
	var titles []string
	for _, f := range matches {
		// Has any change relative to HEAD?
		out1, err1 := r.Git("diff", "--quiet", "--", f)
		out2, err2 := r.Git("diff", "--cached", "--quiet", "--", f)
		_ = out1
		_ = out2
		if err1 == nil && err2 == nil {
			continue // both quiet → unchanged
		}
		data, err := os.ReadFile(f)
		if err != nil {
			continue
		}
		t := extractFirstTitle(string(data))
		if t != "" {
			titles = append(titles, t)
		}
	}
	if len(titles) == 0 {
		return "auto-commit before push"
	}
	return strings.Join(titles, "\n")
}

// extractFirstTitle returns the first `# Title` line in body (with leading
// "# " stripped), or "" if none. Matches the shell's `grep -m1 '^# '`.
func extractFirstTitle(body string) string {
	for _, line := range strings.Split(body, "\n") {
		if strings.HasPrefix(line, "# ") {
			return strings.TrimSpace(strings.TrimPrefix(line, "# "))
		}
	}
	return ""
}

// touchedIssuesNotDone diffs `origin/main..HEAD` for issue files and
// returns the ones whose status is NOT in {done, wontfix, punt}. Used
// by push's not-done warn step. Mirrors check_undone_issues in
// Makefile.workflow.
func touchedIssuesNotDone(baseRef, issuesDir string, r gitRunner) ([]string, error) {
	out, err := r.Git("diff", "--name-only", baseRef+"..HEAD", "--", issuesDir+"/*.md")
	if err != nil {
		return nil, fmt.Errorf("git diff %s..HEAD: %v\n%s", baseRef, err, out)
	}
	touched := splitNonEmptyLines(string(out))
	var notDone []string
	for _, p := range touched {
		// Read from the working tree — the file is on disk at p relative
		// to repo top. Matches the shell `[ -f "$target" ]` guard.
		data, derr := os.ReadFile(p)
		if derr != nil {
			continue
		}
		fm, _, perr := issue.Parse(string(data))
		if perr != nil {
			continue
		}
		st, _ := issue.GetField(fm, "status")
		if !isTerminalStatus(st) {
			notDone = append(notDone, fmt.Sprintf("%s (status: %s)", p, valueOr(st, "unset")))
		}
	}
	return notDone, nil
}

// archiveDoneIssues scans issuesDir for NNNNNN-*.md with terminal status
// and moves them to historyDir. For status=done with a github_issue:
// frontmatter, calls gh issue close (best-effort — failure warns but does
// not abort). Returns the number moved.
func archiveDoneIssues(stderr io.Writer, repo, issuesDir, historyDir string) (int, error) {
	matches, _ := filepath.Glob(filepath.Join(issuesDir, "[0-9][0-9][0-9][0-9][0-9][0-9]-*.md"))
	sort.Strings(matches)
	moved := 0
	for _, p := range matches {
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		fm, _, perr := issue.Parse(string(data))
		if perr != nil {
			continue
		}
		st, _ := issue.GetField(fm, "status")
		if !isTerminalStatus(st) {
			continue
		}
		// status=done + github_issue: → close GitHub issue first.
		if st == "done" && repo != "" {
			if ghNum, ok := issue.GetField(fm, "github_issue"); ok && ghNum != "" {
				cinfo(stderr, fmt.Sprintf("Closing GitHub issue #%s...", ghNum))
				if cerr := ghClient.IssueClose(repo, ghNum, "Fixed on main."); cerr != nil {
					cwarn(stderr, fmt.Sprintf("gh issue close %s failed: %v (continuing)", ghNum, cerr))
				}
			}
		}
		if err := os.MkdirAll(historyDir, 0o755); err != nil {
			return moved, fmt.Errorf("mkdir %s: %v", historyDir, err)
		}
		dest := filepath.Join(historyDir, filepath.Base(p))
		cinfo(stderr, fmt.Sprintf("Archiving %s to %s/", p, historyDir))
		if err := os.Rename(p, dest); err != nil {
			return moved, fmt.Errorf("mv %s → %s: %v", p, dest, err)
		}
		moved++
	}
	return moved, nil
}

// isTerminalStatus reports whether s is one of {done, wontfix, punt} —
// the three statuses that justify archive to history/.
func isTerminalStatus(s string) bool {
	return s == "done" || s == "wontfix" || s == "punt"
}

// splitNonEmptyLines splits text on newlines and drops empties. Used to
// turn `git diff --name-only` and `git ls-files` output into clean slices.
func splitNonEmptyLines(text string) []string {
	text = strings.TrimSpace(text)
	if text == "" {
		return nil
	}
	var out []string
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if line != "" {
			out = append(out, line)
		}
	}
	return out
}
