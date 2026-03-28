# Linting

- `make lint` runs `luacheck` on `lua/` and `tests/`
- Config in `.luacheckrc`
- `lua/**/*.lua`: allows global `vim`
- `tests/**/*.lua`: allows `vim` + busted/plenary globals (`describe`, `it`, `before_each`, `after_each`, `setup`, `teardown`, `pending`, `assert`, `spy`, `stub`, `match`)
- Missing `luacheck` -> fail fast with install message
