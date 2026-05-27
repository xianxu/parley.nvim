// term.go — terminal + small-string helpers shared across sdlc subcommands.
//
// Lifted out of close.go (cinfo/cok/cwarn/die), judge.go (orStr/envOr/
// isSandbox), and state.go (valueOr/truncate) in M4. The duplication
// was already visible at M3 review (close + judge each had their own
// orStr); adding four more subcommands in M4 (fetch/start/lock/setstatus)
// would have turned the implicit cross-file coupling into a maintenance
// landmine. One source of truth per helper, package-local (no internal/
// package — these are CLI-shell-specific, not reusable library code).
package main

import (
	"fmt"
	"io"
	"os"
)

// ── ANSI colors ──────────────────────────────────────────────────────────────
//
// Emitted unconditionally to match close-issue.py's posture. Downstream
// terminals + Makefile wrappers already handle the codes. Stripping for
// CI is a one-flag follow-up, not blocking.

const (
	ansiRed    = "\033[1;31m"
	ansiGreen  = "\033[1;32m"
	ansiYellow = "\033[1;33m"
	ansiCyan   = "\033[1;36m"
	ansiReset  = "\033[0m"
)

// cinfo prints a cyan "==>" header line.
func cinfo(w io.Writer, msg string) { fmt.Fprintf(w, "%s==>%s %s\n", ansiCyan, ansiReset, msg) }

// cok prints a green "[ok]" success line.
func cok(w io.Writer, msg string) { fmt.Fprintf(w, "  %s[ok]%s %s\n", ansiGreen, ansiReset, msg) }

// cwarn prints a yellow "[!]" warning line.
func cwarn(w io.Writer, msg string) { fmt.Fprintf(w, "  %s[!]%s %s\n", ansiYellow, ansiReset, msg) }

// die prints a red "Error: <msg>" to the given writer and exits with
// code 1. Used for hard guardrail failures where we want to bypass
// cobra's default "Error:" prefix.
func die(stderr io.Writer, msg string) {
	fmt.Fprintf(stderr, "%sError: %s%s\n", ansiRed, msg, ansiReset)
	os.Exit(1)
}

// ── small-string helpers ─────────────────────────────────────────────────────

// orStr returns s if non-empty, else fallback. Used to express
// "flag value, defaulting to X" without a flag-defaults rewrite.
func orStr(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

// valueOr is orStr's alias for the cases where the fallback is a
// sentinel render-value (e.g. "?" or "(detached)") rather than an
// option default. Same function, kept as a separate name so prose
// callers read clearly. ("value or fallback for rendering" vs
// "string or default for resolution".)
func valueOr(s, fallback string) string { return orStr(s, fallback) }

// envOr returns os.Getenv(name) if set, else fallback. Centralizes
// the env-default pattern for flag values that may be overridden
// via env (WF_ISSUES_DIR, WF_HISTORY_DIR, AGENT_CMD, etc.).
func envOr(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}

// truncate cuts a string to at most n runes (not bytes), appending an
// ellipsis if it had to cut. Rune-aware so multibyte titles (emoji,
// em-dash, accented chars) don't produce invalid UTF-8 mid-rune.
func truncate(s string, n int) string {
	runes := []rune(s)
	if len(runes) <= n {
		return s
	}
	return string(runes[:n-1]) + "…"
}

// isSandbox detects whether the binary is running inside a Docker-style
// sandbox (used by codex/gemini to gate their auto-approve flags).
func isSandbox() bool {
	if _, err := os.Stat("/.dockerenv"); err == nil {
		return true
	}
	return false
}
