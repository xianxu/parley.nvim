---
id: 000077
status: done
deps: []
created: 2026-04-06
updated: 2026-04-07
---

# openshell sandbox fail to start on a new mac

error message:

```
Copying agent...
Error: unable to connect to beta: unable to connect to endpoint: unable to dial agent endpoint: unable to install agent: unable to copy agent binary: unable to run SCP process: Couldn't open /dev/null: Permission denied
/usr/bin/scp: Connection closed
```

First, document what are the steps a `make sandbox-build` would take. Then trace step by step to find out where that comes from. Whereever applicable, involve user's help for debugging.

## Done when

- [x] `make sandbox` completes without errors and drops into sandbox shell

## Plan

- [x] Document the `make sandbox-build` execution path from Makefile to shell script steps
- [x] Trace the reported `scp` failure to the exact stage that emits `Copying agent...`
- [x] Confirm with user whether the failure happens during `openshell sandbox create` before repo setup starts
- [x] Decide whether the fix belongs in this repo, local environment setup, or upstream OpenShell
- [x] Fix 1: `/dev/null` blocked by landlock — add to `read_write` in `policy.yaml`
- [x] Fix 2: Homebrew openssh used for `openshell sandbox connect` — pin to `/usr/bin/ssh` via PATH
- [x] Fix 3: `sandbox-nuke` didn't clear bootstrap cache — add `nuke` action to `sandbox.sh`

## Log

### 2026-04-06

- Read `tasks/lessons.md`, `TOOLING.md`, `ARCH.md`, `Makefile`, `.openshell/Makefile`, and `.openshell/sandbox.sh`.
- `make sandbox-build` expands to `.openshell/sandbox.sh build $(SANDBOX_NAME)`.
- `cmd_build()` does these phases in order:
  1. Query current sandbox phase with `openshell sandbox list`
  2. If missing, run `openshell sandbox create --name ... --from base --policy .openshell/policy.yaml --auto-providers -- true` in background
  3. In parallel, run `.openshell/overlay/bootstrap.sh` on the host
  4. Regenerate SSH config with `openshell sandbox ssh-config`
  5. Start mutagen bootstrap sync
  6. Run `ensure_setup()`, which only then uses this repo's own `scp` calls for `post-install.sh`, `setup.sh`, and `config.kdl`
  7. Start repo/worktree/git/plenary/state mutagen syncs
- The reported output starts with `Copying agent...`, which does not exist in this repo. That strongly indicates the failing `scp` is inside `openshell sandbox create` during OpenShell agent installation, not this repo's later `scp -q ...` setup steps.
- Because the failure says `Couldn't open /dev/null: Permission denied`, the most likely break is inside the OpenShell CLI / its spawned `scp` process, or the local execution environment around it, before our repo-specific setup begins.
- User confirmed `openshell sandbox create` can complete after clearing a stale `~/.ssh/openshell_known_hosts` entry, but `make sandbox` still fails later.
- Manual isolation showed the failing post-create step is actually Mutagen bootstrap sync:
  `mutagen sync create --name parley-nvim-sandbox-bootstrap --mode one-way-replica --ignore-vcs .openshell/.bootstrap openshell-parley-nvim-sandbox:/tmp/bootstrap`
- Manual `scp` reproduction also fails, both with default mode and legacy `scp -O`, after successful authentication:
  `Couldn't open /dev/null: Permission denied`
- Manual plain-SSH upload works:
  `ssh openshell-parley-nvim-sandbox 'cat >/tmp/test-upload' < .openshell/overlay/setup.sh`
- `ssh -G openshell-parley-nvim-sandbox` no longer shows `/dev/null` in active config after replacing known-host paths with a real file, so the `/dev/null` failure is not explained by current repo-generated SSH config alone.
- Official Mutagen SSH transport docs indicate Mutagen shells out to system `scp` to copy agent binaries and system `ssh` to communicate with them; the only documented transport override is `MUTAGEN_SSH_PATH` for choosing a different OpenSSH installation.
- Local machine currently only has Apple's `/usr/bin/ssh` and `/usr/bin/scp`; Homebrew `openssh` is not installed.
- Current best hypothesis: incompatibility/bug in Apple's OpenSSH 9.9 `scp` path when used through the OpenShell `ssh-proxy` (`russh_0.57.1` on the remote side), rather than a repo bug or sandbox image regression.

### 2026-04-07 — Root causes found and fixed

Three distinct root causes, all in this repo:

**1. `/dev/null` blocked by landlock policy**
- The sandbox container's landlock filesystem policy only listed `/dev/urandom` under `/dev/`. `/dev/null` was unlisted, so any access (open for read or write) was denied.
- `ls -la /dev/null` succeeded (stat doesn't open the fd) but `cat /dev/null`, `echo x > /dev/null`, and `scp` all failed.
- Fix: added `/dev/null` to `read_write` in `.openshell/policy.yaml`. Requires sandbox recreate.
- This was the primary blocker — once fixed, mutagen's bootstrap sync and all scp calls succeeded.

**2. Homebrew openssh used for `openshell sandbox connect`**
- The new mac had Homebrew openssh (`/opt/homebrew/bin/ssh`) earlier in PATH than Apple's `/usr/bin/ssh`.
- Homebrew openssh doesn't support macOS-specific `UseKeychain yes` option in `~/.ssh/config`, and `IgnoreUnknown UseKeychain` was commented out in the user's config.
- `openshell sandbox connect` internally shells out to whichever `ssh` is first in PATH, hitting the Homebrew binary and failing with `Bad configuration option: usekeychain`.
- Fix: `PATH="/usr/bin:$PATH" openshell sandbox connect` in `cmd_connect()` ensures Apple's ssh is used.
- Also set `SSH=/usr/bin/ssh`, `SCP=/usr/bin/scp`, and `MUTAGEN_SSH_PATH=/usr/bin/ssh` at top of `sandbox.sh` for all other calls.

**3. `sandbox-nuke` didn't clear bootstrap cache**
- `sandbox-nuke` was an alias for `sandbox-stop`, which called `cleanup()`. `cleanup()` deleted the sandbox and terminated syncs but left `.openshell/.bootstrap/` intact (including the `.done` sentinel).
- On the next `make sandbox`, bootstrap.sh detected `.done` and skipped all downloads, making nuke feel incomplete.
- Fix: new `nuke` action in `sandbox.sh` calls `cleanup_nuke()` which also `rm -rf`s the bootstrap cache. Makefile `sandbox-nuke` now invokes this directly instead of `sandbox-stop`.
