// lock.go — `sdlc lock [--issue N]` subcommand.
//
// Ports scripts/issue-sync.sh — the issue-file synchronizer that
// commits + pushes workshop/issues/ changes to origin/main even when
// the operator is on a feature branch. Used as the workstream locking
// primitive: agents claim work by flipping status to `working` and
// running `sdlc lock` to broadcast that claim to origin/main.
//
// Two paths in the source script (preserved verbatim here):
//
//  1. On main:    add + commit + push directly.
//  2. On a feature branch:
//     - locate the main worktree via `git worktree list --porcelain`
//     - check main worktree has no uncommitted issue changes
//     - pull --rebase origin main on the main worktree
//     - detect conflicts (files changed on both branches since merge-base)
//     - copy changed issue files from feature worktree → main worktree
//     - commit + push on main worktree
//
// The shell script supports no flags. We add --issue (filter the sync to
// one issue file), --issues-dir (env override), --dry-run.
package main

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/spf13/cobra"

	"github.com/xianxu/ariadne/cmd/sdlc/internal/gitx"
)

// lockFlags holds the parsed flag values for the lock subcommand.
type lockFlags struct {
	Issue     int
	IssuesDir string
	DryRun    bool
}

// NewLockCmd returns the cobra command for `sdlc lock`.
func NewLockCmd() *cobra.Command {
	f := lockFlags{}
	cmd := &cobra.Command{
		Use:           "lock",
		Short:         "Sync workshop/issues/ changes to origin/main (workstream-claim primitive)",
		Long:          "Placeholder — replaced by helptext.MustGet(\"lock\") in main.go.",
		Args:          cobra.NoArgs,
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runLock(cmd.OutOrStdout(), cmd.ErrOrStderr(), &f)
		},
	}
	cmd.Flags().IntVar(&f.Issue, "issue", 0, "sync only this issue's file (default: all changed issue files)")
	cmd.Flags().StringVar(&f.IssuesDir, "issues-dir", envOr("WF_ISSUES_DIR", "workshop/issues"), "directory holding issue files")
	cmd.Flags().BoolVar(&f.DryRun, "dry-run", false, "print what would happen; do not commit/push")
	return cmd
}

// lockRunner is the same gitRunner interface used by start; reused so
// tests can inject capture runners across both verbs.
var lockRunner gitRunner = execGitRunner{}

// runLock dispatches to sync-on-main or sync-on-branch based on the
// current branch, exactly like the shell source.
func runLock(stdout, stderr io.Writer, f *lockFlags) error {
	branch := gitx.Capture("branch", "--show-current")
	if branch == "main" {
		return syncOnMain(stdout, stderr, f, lockRunner)
	}
	return syncOnBranch(stdout, stderr, f, branch, lockRunner)
}

// ── on-main path ─────────────────────────────────────────────────────────────

func syncOnMain(stdout, stderr io.Writer, f *lockFlags, r gitRunner) error {
	changed, err := changedIssueFiles(f, r)
	if err != nil {
		die(stderr, err.Error())
	}
	if len(changed) == 0 {
		cok(stderr, "No issue changes to sync.")
		return nil
	}
	cinfo(stderr, "Syncing issue changes on main...")
	for _, c := range changed {
		fmt.Fprintf(stderr, "  %s\n", c)
	}
	if f.DryRun {
		cinfo(stderr, "dry-run — no commit/push performed")
		return nil
	}
	// Match the shell exactly: git add issues/ (when no --issue filter).
	// With --issue, narrow to that issue's NNNNNN-*.md files.
	addArgs := []string{"add", f.IssuesDir + "/"}
	if f.Issue > 0 {
		id := fmt.Sprintf("%06d", f.Issue)
		matches, _ := filepath.Glob(filepath.Join(f.IssuesDir, id+"-*.md"))
		if len(matches) == 0 {
			die(stderr, fmt.Sprintf("--issue %d: no file matches %s/%s-*.md", f.Issue, f.IssuesDir, id))
		}
		addArgs = append([]string{"add"}, matches...)
	}
	if out, err := r.Git(addArgs...); err != nil {
		die(stderr, fmt.Sprintf("git add: %v\n%s", err, out))
	}
	if out, err := r.Git("commit", "-m", "issue-sync: update issues"); err != nil {
		die(stderr, fmt.Sprintf("commit failed: %v\n%s", err, out))
	}
	if out, err := r.Git("push", "origin", "main"); err != nil {
		die(stderr, fmt.Sprintf("push failed: %v\n%s", err, out))
	}
	cok(stderr, "Issues synced and pushed to origin/main.")
	fmt.Fprintln(stdout, "synced")
	return nil
}

// ── on-branch path ───────────────────────────────────────────────────────────

func syncOnBranch(stdout, stderr io.Writer, f *lockFlags, branch string, r gitRunner) error {
	changed, err := changedIssueFiles(f, r)
	if err != nil {
		die(stderr, err.Error())
	}
	if len(changed) == 0 {
		cok(stderr, "No issue changes to sync.")
		return nil
	}
	cinfo(stderr, fmt.Sprintf("Issue files changed on branch '%s':", branch))
	for _, c := range changed {
		fmt.Fprintf(stderr, "  %s\n", c)
	}

	// 1. Find the main worktree.
	mainPath, err := findMainWorktree(r)
	if err != nil {
		die(stderr, err.Error())
	}

	// 2. Verify main worktree is on main.
	mainBranchOut, err := r.GitInDir(mainPath, "branch", "--show-current")
	if err != nil {
		die(stderr, fmt.Sprintf("git -C %s branch --show-current: %v\n%s", mainPath, err, mainBranchOut))
	}
	mainBranch := strings.TrimSpace(string(mainBranchOut))
	if mainBranch != "main" {
		die(stderr, fmt.Sprintf("expected main worktree to be on 'main', but it's on '%s'", mainBranch))
	}

	// 3. Check main worktree has no uncommitted issue changes.
	mainDirty, err := mainHasUncommittedIssueChanges(mainPath, f.IssuesDir, r)
	if err != nil {
		die(stderr, err.Error())
	}
	if len(mainDirty) > 0 {
		die(stderr, fmt.Sprintf("main worktree has uncommitted issue changes. Commit or stash them first:\n  %s",
			strings.Join(mainDirty, "\n  ")))
	}

	cok(stderr, fmt.Sprintf("Main worktree found at: %s", mainPath))

	if f.DryRun {
		cinfo(stderr, "dry-run — skipping pull/copy/commit/push")
		return nil
	}

	// 4. Pull --rebase origin main on main worktree.
	cinfo(stderr, "Pulling latest main from origin...")
	if out, err := r.GitInDir(mainPath, "pull", "--rebase", "origin", "main"); err != nil {
		die(stderr, fmt.Sprintf("failed to pull main from origin: %v\n%s", err, out))
	}

	// 5. Compute merge base and detect conflicts.
	mergeBase := strings.TrimSpace(string(mustGitOutput(r, "merge-base", "main", "HEAD")))
	if mergeBase == "" {
		die(stderr, "cannot find merge base between main and HEAD")
	}
	mainChangedOut, _ := r.Git("diff", "--name-only", mergeBase, "main", "--", f.IssuesDir+"/")
	mainChanged := map[string]bool{}
	for _, line := range strings.Split(strings.TrimSpace(string(mainChangedOut)), "\n") {
		if line != "" {
			mainChanged[line] = true
		}
	}
	var conflicts []string
	for _, c := range changed {
		if mainChanged[c] {
			conflicts = append(conflicts, c)
		}
	}
	if len(conflicts) > 0 {
		fmt.Fprintf(stderr, "%sConflict detected!%s\n", ansiRed, ansiReset)
		fmt.Fprintln(stderr, "These issue files were changed on both your branch and main:")
		for _, c := range conflicts {
			fmt.Fprintf(stderr, "  %s\n", c)
		}
		fmt.Fprintf(stderr, "\nTo resolve:\n")
		fmt.Fprintf(stderr, "  1. cd %s\n", mainPath)
		fmt.Fprintf(stderr, "  2. For each file above, open it and manually merge your changes.\n")
		wtRoot, _ := gitx.RepoTopLevel()
		fmt.Fprintf(stderr, "     Your branch versions are at: %s\n", wtRoot)
		fmt.Fprintf(stderr, "  3. git add %s/\n", f.IssuesDir)
		fmt.Fprintf(stderr, "  4. git commit -m \"issue-sync: resolve conflicts\"\n")
		fmt.Fprintf(stderr, "  5. git push origin main\n")
		os.Exit(1)
	}

	cok(stderr, "No conflicts detected.")

	// 6. Copy changed files to main worktree.
	cinfo(stderr, "Copying issue files to main worktree...")
	wtRoot, _ := gitx.RepoTopLevel()
	for _, c := range changed {
		src := filepath.Join(wtRoot, c)
		dest := filepath.Join(mainPath, c)
		if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
			die(stderr, fmt.Sprintf("mkdir %s: %v", filepath.Dir(dest), err))
		}
		data, err := os.ReadFile(src)
		if err != nil {
			die(stderr, fmt.Sprintf("read %s: %v", src, err))
		}
		if err := os.WriteFile(dest, data, 0o644); err != nil {
			die(stderr, fmt.Sprintf("write %s: %v", dest, err))
		}
		fmt.Fprintf(stderr, "  %s\n", c)
	}

	// 7. Commit + push on main worktree.
	cinfo(stderr, "Committing and pushing on main...")
	if out, err := r.GitInDir(mainPath, "add", f.IssuesDir+"/"); err != nil {
		die(stderr, fmt.Sprintf("git -C %s add: %v\n%s", mainPath, err, out))
	}
	commitMsg := fmt.Sprintf("issue-sync: update issues from branch '%s'", branch)
	if out, err := r.GitInDir(mainPath, "commit", "-m", commitMsg); err != nil {
		die(stderr, fmt.Sprintf("commit failed: %v\n%s", err, out))
	}
	if out, err := r.GitInDir(mainPath, "push", "origin", "main"); err != nil {
		die(stderr, fmt.Sprintf("push failed: %v\n%s", err, out))
	}
	cok(stderr, "Issues synced to main and pushed to origin.")
	fmt.Fprintln(stdout, "synced")
	return nil
}

// ── helpers ──────────────────────────────────────────────────────────────────

// changedIssueFiles returns the union of:
//   - `git diff --name-only HEAD -- <issuesDir>/`   (working-tree + staged
//     relative to HEAD)
//   - `git diff --cached --name-only -- <issuesDir>/`  (staged-only)
//   - `git ls-files --others --exclude-standard -- <issuesDir>/`  (untracked)
//
// Sorted + deduped. If f.Issue is set, filter to only the matching
// NNNNNN-*.md file.
//
// Matches issue-sync.sh's changed_issue_files() — note the union includes
// "diff HEAD" (which already covers cached) plus "diff --cached" separately
// (redundant but preserved for parity); de-dup happens at the sort step.
func changedIssueFiles(f *lockFlags, r gitRunner) ([]string, error) {
	queries := [][]string{
		{"diff", "--name-only", "HEAD", "--", f.IssuesDir + "/"},
		{"diff", "--cached", "--name-only", "--", f.IssuesDir + "/"},
		{"ls-files", "--others", "--exclude-standard", "--", f.IssuesDir + "/"},
	}
	seen := map[string]struct{}{}
	var out []string
	for _, q := range queries {
		raw, err := r.Git(q...)
		if err != nil {
			// Mirror the shell `|| true` swallow: empty result, no error.
			continue
		}
		for _, line := range strings.Split(strings.TrimSpace(string(raw)), "\n") {
			if line == "" {
				continue
			}
			if _, ok := seen[line]; ok {
				continue
			}
			seen[line] = struct{}{}
			out = append(out, line)
		}
	}
	sort.Strings(out)

	if f.Issue > 0 {
		id := fmt.Sprintf("%06d", f.Issue)
		var filtered []string
		for _, p := range out {
			if strings.HasPrefix(filepath.Base(p), id+"-") {
				filtered = append(filtered, p)
			}
		}
		out = filtered
	}
	return out, nil
}

// findMainWorktree parses `git worktree list --porcelain` and returns
// the path of the worktree on branch `main`. Empty + error if none.
//
// Matches the awk pipeline in issue-sync.sh:
//
//	awk '/^worktree /{path=$2} /branch refs\/heads\/main$/{print path}'
func findMainWorktree(r gitRunner) (string, error) {
	out, err := r.Git("worktree", "list", "--porcelain")
	if err != nil {
		return "", fmt.Errorf("git worktree list: %v\n%s", err, out)
	}
	var currentPath, mainPath string
	scanner := bufio.NewScanner(bytes.NewReader(out))
	for scanner.Scan() {
		line := scanner.Text()
		switch {
		case strings.HasPrefix(line, "worktree "):
			currentPath = strings.TrimPrefix(line, "worktree ")
		case line == "branch refs/heads/main":
			mainPath = currentPath
		}
	}
	if mainPath == "" {
		return "", fmt.Errorf("could not find a worktree on branch 'main'. Is main checked out somewhere?")
	}
	return mainPath, nil
}

// mainHasUncommittedIssueChanges returns the list of issue files in the
// main worktree that have uncommitted changes (working + staged).
func mainHasUncommittedIssueChanges(mainPath, issuesDir string, r gitRunner) ([]string, error) {
	dirty := map[string]struct{}{}
	for _, q := range [][]string{
		{"diff", "--name-only", "--", issuesDir + "/"},
		{"diff", "--cached", "--name-only", "--", issuesDir + "/"},
	} {
		raw, err := r.GitInDir(mainPath, q...)
		if err != nil {
			continue // mirror shell `|| true`
		}
		for _, line := range strings.Split(strings.TrimSpace(string(raw)), "\n") {
			if line != "" {
				dirty[line] = struct{}{}
			}
		}
	}
	var out []string
	for k := range dirty {
		out = append(out, k)
	}
	sort.Strings(out)
	return out, nil
}

// mustGitOutput is a thin shim that returns r.Git's stdout but discards
// errors (the shell uses `|| die` for these — we let the empty result
// trigger our own die() upstream).
func mustGitOutput(r gitRunner, args ...string) []byte {
	out, _ := r.Git(args...)
	return out
}
