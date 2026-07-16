---
id: 000030
status: wontfix
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# security fix to openshell

Findings

  1. Critical: the advertised OpenShell policy boundary is not enforced, so this is effectively
     a normal Docker container with a false sense of isolation. The runtime path is just docker
     run ... sleep infinity and docker exec ... zsh, with no reference to policy.yaml, no
     OpenShell runtime, and no policy engine invocation. The Docker image is built from plain
     Ubuntu, not an OpenShell base. That means the claimed deny-by-default filesystem/network
     policy in the spec is not real today. See .openshell/Makefile:47, .openshell/
     Makefile:55, .openshell/Dockerfile:1, .openshell/Dockerfile:3, .openshell/policy.yaml:1,
     specs/infra/openshell.md:47.
  2. High: the host SSH agent is exposed directly into the container, then loosened with chmod
     777, so any process inside the container can use the user’s SSH identities. This is a real
     credential-boundary break, especially because the same setup intentionally gives agents
     full auto-approval. A malicious or compromised tool in the container can authenticate to
     GitHub or other SSH-reachable services as the host user without extracting the private key
     itself. See .openshell/Makefile:52, .openshell/Makefile:53, .openshell/
     Makefile:56, .openshell/dotfiles/zshrc:73, .openshell/dotfiles/zshrc:74, .openshell/
     dotfiles/zshrc:75.
  3. High: there is no runtime hardening on the container at all. I do not see --cap-drop,
     --security-opt=no-new-privileges, seccomp/AppArmor settings, a read-only rootfs, tmpfs
     isolation, or Docker-level network restrictions. Combined with finding 1, the container
     has ordinary Docker outbound networking despite the repo claiming restrictive egress
     policy. See .openshell/Makefile:47, .openshell/policy.yaml:14, specs/infra/
     openshell.md:49.
  4. Medium: the build chain pulls and executes multiple remote installer scripts without
     pinning or checksum verification. That is a supply-chain risk for anyone rebuilding the
     image, and it is amplified by the fact that the resulting environment is then treated as a
     trusted sandbox. See .openshell/Dockerfile:36, .openshell/Dockerfile:51, .openshell/
     Dockerfile:69, .openshell/Dockerfile:74.
  5. Medium: the repo and ../worktree are mounted read-write from the host, so compromise of
     the container immediately becomes compromise of the checked-out source tree and adjacent
     worktrees. That may be intentional for developer ergonomics, but it means this is not a
     hermetic or low-blast-radius environment in the way the docs describe. See .openshell/
     Makefile:49, .openshell/Makefile:50, specs/infra/openshell.md:33.

  Open Questions / Assumptions

  - I assumed the review target is the checked-in .openshell implementation only. I did not
    find an external bootstrap.sh or any hidden runtime wrapper that would apply policy.yaml.
  - I treated “security hole” relative to the documented model: a container that claims
    enforced policy isolation but does not actually enforce it is a security issue, not just
    documentation drift.

  Summary

  The primary problem is architectural: this is not an OpenShell VM or even an OpenShell-
  enforced sandbox yet. It is a convenience Docker container with broad host integration and
  agent auto-approval. If you want, I can turn this into a remediation plan ranked by impact
  and effort.

## Done when

N/A — superseded by issue 000031

## Plan

Superseded by issue 000031 (migrate to real OpenShell runtime). All findings become moot once the actual policy engine is in place.

## Log

### 2026-03-29
- Implemented fixes for findings 2 and 3, then reverted
- Discovered OpenShell runtime is publicly available (https://github.com/NVIDIA/OpenShell)
- All 5 findings are addressed by migrating to the real runtime — created issue 000031
- Marked wontfix: patching a hand-rolled container that's being replaced

