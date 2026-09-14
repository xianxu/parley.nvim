# Optional OpenShell development environment

OpenShell is a maintainer's external agent sandbox integration, not part of the
Parley application runtime. Parley does not automatically sandbox its model tools
with OpenShell. File-tool access instead follows Parley's
[repository/neighborhood policy](repo_mode.md).

A public checkout and the installed app do not include the sandbox bootstrap,
policy, sync configuration or agent credentials. Maintainer bootstrap may restore
additional infrastructure in a configured development environment. Consult that
environment's current commands and policy before using it; sandbox availability,
network policy and image behavior are not Parley release guarantees.

For ordinary development, use the standalone commands in `TOOLING.md` and the
[test harness](test_harness.md). No OpenShell installation is required.
