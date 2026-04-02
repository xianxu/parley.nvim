# Linting

- `make lint` runs `luacheck` on `lua/` and `tests/`
- Config in `.luacheckrc`; allows `vim` global in source, busted/plenary globals in tests
- Missing `luacheck` -> fail fast with install message
