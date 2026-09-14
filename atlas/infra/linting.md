# Linting

Contributor tooling; running Parley does not require luacheck. See `TOOLING.md`
for installation and the [test harness](test_harness.md) for verification.

- `make lint` runs `luacheck` on `lua/` and `tests/`
- Config in `.luacheckrc`; allows `vim` global in source, busted/plenary globals in tests
- Missing `luacheck` -> fail fast with install message
