// merge.go — `sdlc merge` subcommand. Ports the `merge:` Make target.
//
// The longest + most safety-conscious script in the lift table. Runs from
// inside a worktree (refuses main), guards every irreversible step, ends
// with worktree cleanup. Sequence (Makefile.workflow ~lines 390-491):
//
//   1. branch != main / non-empty
//   2. no uncommitted changes
//   3. upstream configured
//   4. branch not ahead of upstream
//   5. pre-merge judges (plan + specs + lessons, skippable with --no-judge)
//   6. find main worktree path
//   7. show unmerged commits (informational)
//   8. not-done issue warn (vs main)
//   9. interactive confirmation (skippable with --yes)
//  10. gh pr list → either merge existing PR or offer create/remove
//  11. archive done/wontfix/punt issues into history/ in the MAIN worktree
//  12. worktree remove + branch delete; write main path to .goto in old worktree
package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/spf13/cobra"

	"github.com/xianxu/ariadne/cmd/sdlc/internal/gitx"
	"github.com/xianxu/ariadne/cmd/sdlc/internal/issue"
	"github.com/xianxu/ariadne/cmd/sdlc/internal/judge"
)

// mergeFlags holds the parsed flag values for the merge subcommand.
type mergeFlags struct {
	Yes        bool
	NoJudge    bool
	DryRun     bool
	IssuesDir  string
	HistoryDir string
}

// mergeRunner is the package-level runner for merge (test seam). Type
// lives in runner.go.
var mergeRunner gitRunner = execGitRunner{}

// mergePrompter is a tiny indirection over stdin so tests can drive the
// confirmation prompts deterministically. Production wraps os.Stdin.
var mergePrompter prompter = stdinPrompter{}

// prompter abstracts the "read a line, return trimmed text" surface.
type prompter interface {
	Ask(question string, w io.Writer) string
}

type stdinPrompter struct{}

func (stdinPrompter) Ask(question string, w io.Writer) string {
	fmt.Fprint(w, question)
	scanner := bufio.NewScanner(os.Stdin)
	if scanner.Scan() {
		return strings.TrimSpace(scanner.Text())
	}
	return ""
}

// NewMergeCmd returns the cobra command for `sdlc merge`.
func NewMergeCmd() *cobra.Command {
	f := mergeFlags{}
	cmd := &cobra.Command{
		Use:           "merge",
		Short:         "Merge the current worktree branch via GitHub, archive done issues, clean up worktree",
		Long:          "Placeholder — replaced by helptext.MustGet(\"merge\") in main.go.",
		Args:          cobra.NoArgs,
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runMerge(cmd.OutOrStdout(), cmd.ErrOrStderr(), &f)
		},
	}
	cmd.Flags().BoolVar(&f.Yes, "yes", false, "skip the final irreversible-merge confirmation AND not-done warn")
	cmd.Flags().BoolVar(&f.NoJudge, "no-judge", false, "skip pre-merge judges (emergency-only)")
	cmd.Flags().BoolVar(&f.DryRun, "dry-run", false, "print would-be operations; do not merge or clean up")
	cmd.Flags().StringVar(&f.IssuesDir, "issues-dir", envOr("WF_ISSUES_DIR", "workshop/issues"), "directory holding issue files")
	cmd.Flags().StringVar(&f.HistoryDir, "history-dir", envOr("WF_HISTORY_DIR", "workshop/history"), "directory for archived issues")
	return cmd
}

// runMerge dispatches the merge workflow.
func runMerge(stdout, stderr io.Writer, f *mergeFlags) error {
	// ── 1. Refuse if main / empty branch ────────────────────────────────────
	branch := gitx.Capture("branch", "--show-current")
	if branch == "" || branch == "main" {
		die(stderr, fmt.Sprintf("sdlc merge must be run from a worktree branch (current: %s)", valueOr(branch, "(detached)")))
	}
	cinfo(stderr, fmt.Sprintf("Branch: %s", branch))

	// ── 2. No uncommitted changes ───────────────────────────────────────────
	dirtyOut, err := mergeRunner.Git("status", "--porcelain")
	if err != nil {
		die(stderr, fmt.Sprintf("git status: %v\n%s", err, dirtyOut))
	}
	dirty := strings.TrimSpace(string(dirtyOut))
	if dirty != "" {
		fmt.Fprintf(stderr, "  %s[x]%s Uncommitted changes found — cannot merge\n", ansiRed, ansiReset)
		fmt.Fprintln(stderr, dirty)
		die(stderr, "commit or stash uncommitted changes before merging")
	}
	cok(stderr, "No uncommitted changes")

	// ── 3. Upstream configured ──────────────────────────────────────────────
	upstream := gitx.Capture("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
	if upstream == "" {
		fmt.Fprintf(stderr, "  %s[x]%s No upstream configured for %s\n", ansiRed, ansiReset, branch)
		die(stderr, fmt.Sprintf("push the branch first (e.g. sdlc pr, or git push -u origin %s)", branch))
	}

	// ── 4. Branch not ahead of upstream ─────────────────────────────────────
	aheadStr := gitx.Capture("rev-list", "--count", upstream+"..HEAD")
	ahead, _ := strconv.Atoi(aheadStr)
	if ahead > 0 {
		fmt.Fprintf(stderr, "  %s[x]%s Unpushed local commits detected: %d commit(s) ahead of %s\n",
			ansiRed, ansiReset, ahead, upstream)
		die(stderr, "push your branch before merging")
	}
	cok(stderr, fmt.Sprintf("No unpushed local commits (HEAD synced with %s)", upstream))

	// ── 5. Pre-merge judges ─────────────────────────────────────────────────
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

	// ── 6. Find main worktree ───────────────────────────────────────────────
	mainPath, err := findMainWorktree(mergeRunner)
	if err != nil {
		die(stderr, fmt.Sprintf("find main worktree: %v", err))
	}
	cok(stderr, fmt.Sprintf("Main worktree: %s", mainPath))

	wtPath, _ := gitx.RepoTopLevel()

	repo, err := detectRepo()
	if err != nil {
		die(stderr, err.Error())
	}

	// ── 7. Show unmerged commits ────────────────────────────────────────────
	unmergedOut, _ := mergeRunner.Git("log", "main..HEAD", "--oneline")
	unmerged := strings.TrimRight(string(unmergedOut), "\n")
	if unmerged != "" {
		cok(stderr, "Unmerged local commits found:")
		for _, line := range strings.Split(unmerged, "\n") {
			fmt.Fprintf(stderr, "       %s\n", line)
		}
	} else {
		cok(stderr, "No unmerged local commits (branch is clean)")
	}

	// ── 8. Not-done issue warn (vs main) ────────────────────────────────────
	notDone, _ := touchedIssuesNotDone("main", f.IssuesDir, mergeRunner)
	if len(notDone) > 0 && !f.Yes && !f.DryRun {
		fmt.Fprintf(stderr, "  %s[!]%s Touched issue files that are NOT done:\n", ansiYellow, ansiReset)
		for _, p := range notDone {
			fmt.Fprintf(stderr, "       %s\n", p)
		}
		ans := mergePrompter.Ask("Continue anyway? [y/N] ", stderr)
		if ans != "y" && ans != "Y" {
			die(stderr, "aborted by operator")
		}
	} else if len(notDone) > 0 && f.Yes {
		cwarn(stderr, fmt.Sprintf("--yes: continuing past %d not-done issue(s)", len(notDone)))
	}

	// ── 9. Interactive confirmation ─────────────────────────────────────────
	if !f.Yes && !f.DryRun {
		ans := mergePrompter.Ask("Final confirmation: proceed with irreversible merge/cleanup actions? [y/N] ", stderr)
		if ans != "y" && ans != "Y" {
			die(stderr, "aborted by operator")
		}
	}

	if f.DryRun {
		cinfo(stderr, "dry-run — skipping merge / archive / worktree cleanup")
		fmt.Fprintf(stdout, "Would: gh pr merge ... (or offer to create) for %s\n", branch)
		fmt.Fprintf(stdout, "Would: archive done issues under %s/%s/\n", mainPath, f.HistoryDir)
		fmt.Fprintf(stdout, "Would: git worktree remove %s\n", wtPath)
		fmt.Fprintf(stdout, "Would: git branch -D %s\n", branch)
		return nil
	}

	// ── 10. Find PR (or offer create / remove) ──────────────────────────────
	prNumber, _ := ghClient.PRListForBranch(repo, branch)
	if prNumber != "" {
		cok(stderr, fmt.Sprintf("Open PR found: #%s", prNumber))
		cinfo(stderr, fmt.Sprintf("Merging PR #%s (%s) into main via GitHub...", prNumber, branch))
		if err := ghClient.PRMerge(repo, branch); err != nil {
			die(stderr, err.Error())
		}
		cinfo(stderr, "Pulling main...")
		if out, gerr := mergeRunner.GitInDir(mainPath, "pull"); gerr != nil {
			die(stderr, fmt.Sprintf("git -C %s pull: %v\n%s", mainPath, gerr, out))
		}
	} else {
		cwarn(stderr, fmt.Sprintf("No open PR for branch %s", branch))
		if unmerged != "" {
			ans := mergePrompter.Ask("Would you like to create a pull request first? [Y/n] ", stderr)
			if ans != "n" && ans != "N" {
				die(stderr, "run `sdlc pr` to create a PR, then re-run `sdlc merge`")
			}
			ans2 := mergePrompter.Ask("Remove worktree without merging? [y/N] ", stderr)
			if ans2 != "y" && ans2 != "Y" {
				die(stderr, "aborted by operator")
			}
		}
		// Falls through to archive + worktree removal regardless — the
		// shell does the same. If no unmerged, we silently proceed.
	}

	// ── 11. Archive done issues in MAIN worktree ────────────────────────────
	moved, err := archiveDoneIssuesInDir(stderr, repo, mainPath, f.IssuesDir, f.HistoryDir)
	if err != nil {
		die(stderr, err.Error())
	}
	if moved > 0 {
		cinfo(stderr, "Committing archived history in main...")
		if out, gerr := mergeRunner.GitInDir(mainPath, "add", f.IssuesDir+"/", f.HistoryDir+"/"); gerr != nil {
			die(stderr, fmt.Sprintf("git -C %s add: %v\n%s", mainPath, gerr, out))
		}
		if out, gerr := mergeRunner.GitInDir(mainPath, "commit", "-m", "archive completed issues to history"); gerr != nil {
			die(stderr, fmt.Sprintf("git -C %s commit: %v\n%s", mainPath, gerr, out))
		}
		if out, gerr := mergeRunner.GitInDir(mainPath, "push"); gerr != nil {
			die(stderr, fmt.Sprintf("git -C %s push: %v\n%s", mainPath, gerr, out))
		}
	}

	// ── 12. Worktree cleanup ────────────────────────────────────────────────
	cinfo(stderr, fmt.Sprintf("Removing worktree at %s...", wtPath))
	// Run worktree remove + branch delete from the MAIN worktree, since
	// removing the current worktree from within itself is undefined.
	// Best-effort (matches shell `|| true`).
	if out, gerr := mergeRunner.GitInDir(mainPath, "worktree", "remove", wtPath); gerr != nil {
		cwarn(stderr, fmt.Sprintf("git worktree remove %s: %v\n%s", wtPath, gerr, out))
	}
	if out, gerr := mergeRunner.GitInDir(mainPath, "branch", "-D", branch); gerr != nil {
		cwarn(stderr, fmt.Sprintf("git branch -D %s: %v\n%s", branch, gerr, out))
	}
	// .goto in the soon-to-be-removed worktree points back to main, so
	// `g` after re-creating the dir lands the operator in main.
	gotoPath := filepath.Join(wtPath, ".goto")
	if err := os.WriteFile(gotoPath, []byte(mainPath), 0o644); err != nil {
		cwarn(stderr, fmt.Sprintf(".goto write failed: %v", err))
	}
	cok(stderr, "Done. Run: g (to cd back to main)")
	return nil
}

// archiveDoneIssuesInDir is the merge-side equivalent of push.go's
// archiveDoneIssues, but it scans + mutates inside the main worktree
// at mainPath (so the archive commit lands on main, not on the feature
// branch).
func archiveDoneIssuesInDir(stderr io.Writer, repo, mainPath, issuesDir, historyDir string) (int, error) {
	issuesFull := filepath.Join(mainPath, issuesDir)
	historyFull := filepath.Join(mainPath, historyDir)
	matches, _ := filepath.Glob(filepath.Join(issuesFull, "[0-9][0-9][0-9][0-9][0-9][0-9]-*.md"))
	sort.Strings(matches)
	moved := 0
	cinfo(stderr, fmt.Sprintf("Archiving completed issues to %s/...", historyDir))
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
		// Merge target's shell DOES NOT call gh issue close — only push:
		// closes GH issues. We mirror that. (Rationale: PR merge itself
		// closes the linked GH issue via the "Fixes #N" body, so a second
		// `gh issue close` would be redundant.) Repo param kept in
		// signature for API symmetry with push's archive helper.
		_ = repo
		if err := os.MkdirAll(historyFull, 0o755); err != nil {
			return moved, fmt.Errorf("mkdir %s: %v", historyFull, err)
		}
		dest := filepath.Join(historyFull, filepath.Base(p))
		fmt.Fprintf(stderr, "  Moving %s to %s/\n", filepath.Base(p), historyDir)
		if err := os.Rename(p, dest); err != nil {
			return moved, fmt.Errorf("mv %s → %s: %v", p, dest, err)
		}
		moved++
	}
	return moved, nil
}
