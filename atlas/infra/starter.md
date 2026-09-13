# Starter profile

The single editable `packaging/starter-config/init.lua` is the app entry under
`NVIM_APPNAME=parley`. It bootstraps pinned Lazy and editor dependencies, then
loads a released Parley version. Packaging can supply `PARLEY_RUNTIME` to use its
installed release. A profile initializer directory owns staged Git work and
serializes first installation; dead or incomplete ownership requires explicit
recovery instead of stealing a competing initializer's work.

`starter_config.options(roots, key)` is the pure profile policy projection.
`starter_profile.client_key(dir)` publishes one private random token atomically;
it is distinct from provider OAuth credentials and proxy management credentials.
`starter.start()` applies the policy, creates or reopens one welcome chat, and
registers `ParleyConnect`. `starter.connect()` ensures the managed proxy exists
before invoking its existing login command. Ordinary plugin setup never loads
these modules automatically.

`cliproxy.live_models.tools` flows through the shared `live_agent_options` into
`cliproxy_catalog.build_agent` for both picking and restoring live models. An
explicit empty table keeps local tools disabled; omission retains `@all`.

All writable profile artifacts belong to Neovim's config/data/state/cache roots;
the proxy auth directory is explicitly profile-local. Welcome discovery recovers
the sole ordinary chat in the dedicated welcome directory. Uninstall stops the
owned managed proxy before removing those roots. See the
[starter guide](../../packaging/starter-config/README.md) for commands and recovery.

`scripts/check-starter.py` rejects personal configuration markers in the artifact
and its policy source. Hermetic startup tests inspect effective Parley setup,
not just returned options; local Git/process fixtures exercise bootstrap races
and failures, followed by live upstream bootstrap conformance at release.
