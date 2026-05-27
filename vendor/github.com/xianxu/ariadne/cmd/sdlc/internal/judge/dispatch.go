package judge

import (
	"context"
	"fmt"
	"io"
	"os/exec"
	"strings"
)

// AgentCLI names a coding-agent CLI. The default is "claude"; the
// shell script supports "codex" and "gemini" via $AGENT_CMD. We mirror
// that surface so `make check-*` shims (env-driven) and `sdlc judge`
// (flag-driven) target the same agents.
type AgentCLI string

const (
	AgentClaude AgentCLI = "claude"
	AgentCodex  AgentCLI = "codex"
	AgentGemini AgentCLI = "gemini"
)

// DispatchOptions configures one invocation.
type DispatchOptions struct {
	Agent        AgentCLI
	Prompt       string
	AllowedTools string // for claude; ignored by codex/gemini
	IsSandbox    bool   // if true, codex/gemini get auto-approve flags
	Stdout       io.Writer
	Stderr       io.Writer
}

// Run is the package-level subprocess shim. Tests replace it with a
// fake to assert the right command line / capture without spawning a
// real agent process. Production execs the binary.
var Run = func(ctx context.Context, name string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	return cmd.CombinedOutput()
}

// BuildArgs returns the argv (binary name + flags + final prompt) for
// invoking the chosen agent. Exposed for tests + --dry-run callers
// that want to print the would-be command line.
func BuildArgs(opts DispatchOptions) (name string, args []string, err error) {
	switch opts.Agent {
	case AgentClaude, "":
		args = []string{
			"-p",
			"--allowedTools", opts.AllowedTools,
			"--permission-mode", "bypassPermissions",
			opts.Prompt,
		}
		return "claude", args, nil

	case AgentCodex:
		args = []string{"exec"}
		if opts.IsSandbox {
			args = append(args, "--full-auto")
		}
		args = append(args, opts.Prompt)
		return "codex", args, nil

	case AgentGemini:
		args = []string{}
		if opts.IsSandbox {
			args = append(args, "--yolo")
		}
		args = append(args, "-p", opts.Prompt)
		return "gemini", args, nil

	default:
		return "", nil, fmt.Errorf("unknown agent: %q (supported: claude, codex, gemini)", opts.Agent)
	}
}

// Dispatch invokes the agent CLI with the given prompt and returns the
// captured output (stdout + stderr combined, matching the shell's eval
// posture). The Outcome classification is the caller's responsibility
// via Classify(); Dispatch's job is just to run the agent and return
// what it said.
//
// Exit-code policy (review I3):
//
//   - subprocess fails to launch (binary missing, permission denied,
//     ctx cancelled, unknown agent name) → return error.
//   - subprocess runs and exits non-zero (any output) → swallow the
//     exit error, return the output for Classify(). Matches shell's
//     `|| true` and lets agents emit "found X violations, exit 1"
//     without us treating it as a binary-launch failure.
//
// In particular: empty-output + non-zero exit is *not* a launch failure
// — Classify() will mark it as Failure based on the empty-output rule.
// This keeps the binary/agent failure modes cleanly separated.
func Dispatch(ctx context.Context, opts DispatchOptions) (output string, err error) {
	name, args, err := BuildArgs(opts)
	if err != nil {
		return "", err
	}
	out, runErr := Run(ctx, name, args...)
	if _, ok := runErr.(*exec.ExitError); ok {
		// Subprocess ran but exited non-zero. Surface the output (may
		// be empty); let Classify() interpret. Matches the shell.
		return string(out), nil
	}
	if runErr != nil {
		// Real launch failure: binary missing, ctx cancelled, etc.
		return string(out), fmt.Errorf("dispatch %s: %w", name, runErr)
	}
	return string(out), nil
}

// FormatCommandLine returns a shell-safe rendering of the would-be
// command, suitable for printing under --dry-run. It does NOT actually
// exec anything.
func FormatCommandLine(opts DispatchOptions) (string, error) {
	name, args, err := BuildArgs(opts)
	if err != nil {
		return "", err
	}
	parts := []string{name}
	for _, a := range args {
		parts = append(parts, shellQuote(a))
	}
	return strings.Join(parts, " "), nil
}

// shellQuote wraps strings containing whitespace or shell metacharacters
// in single quotes (with internal single quotes escaped). Used only for
// --dry-run display; production Dispatch passes args through exec
// directly so quoting isn't an exec-safety concern.
func shellQuote(s string) string {
	if !strings.ContainsAny(s, " \t\n'\"$`\\|&;<>(){}*?[]#~=") {
		return s
	}
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}
