---
id: 000022
status: done
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# ssh secret not available on sandbox

## Done when

- `make push` works from inside the sandbox (SSH agent forwarding lets `git push` authenticate with GitHub)

## Plan

- [x] Diagnose: `SSH_AUTH_SOCK` not set on host, so the socket mount in `docker run` was empty
- [x] Considered mounting `~/.ssh` read-only — rejected (exposes private key to sandbox processes)
- [x] Fix: keep existing agent-forwarding approach (`-v $SSH_AUTH_SOCK:/ssh-agent`), configure host properly
- [x] User: add `export SSH_AUTH_SOCK=$(launchctl asuser $(id -u) launchctl getenv SSH_AUTH_SOCK)` to `~/.zshrc`
- [x] User: run `ssh-add --apple-use-keychain ~/.ssh/id_ed25519` to load key
- [ ] Verify: `ssh -T git@github.com` works inside sandbox
- [ ] Verify: `make push` succeeds inside sandbox

## Log

### 2026-03-29

- Root cause: host shell had no `SSH_AUTH_SOCK` exported, so the `-v "$SSH_AUTH_SOCK:/ssh-agent"` mount in `.openshell/Makefile` was empty
- macOS SSH agent is running (`com.openssh.ssh-agent` via launchd) but socket path wasn't in env
- Also: no keys were loaded into the agent (`ssh-add -l` showed no identities)
- Briefly tried Docker Desktop's `/run/host-services/ssh-agent.sock` — doesn't exist on this setup
- Solution: configure host zshrc + load key, existing Makefile plumbing is correct

