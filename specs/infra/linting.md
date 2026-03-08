# Spec: Linting

## Overview
Parley uses `luacheck` as its Lua static analyzer for plugin code and tests.

## Scope
- `make lint` MUST run `luacheck` on both `lua/` and `tests/`.
- Linting configuration MUST live in `.luacheckrc`.

## Baseline Rules
- Runtime code in `lua/**/*.lua` MUST allow Neovim's global `vim`.
- Test code in `tests/**/*.lua` MUST allow Neovim global `vim` and read-only busted/plenary globals (`describe`, `it`, `before_each`, `after_each`, `setup`, `teardown`, `pending`, `assert`, `spy`, `stub`, `match`).

## Tooling Behavior
- If `luacheck` is not installed, `make lint` MUST fail fast with an actionable install message.
