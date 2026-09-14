# Raw Mode

Raw logging writes per-chat side files for inspecting what Parley sent and what
the provider returned. The master switch `raw_mode.enable` defaults to `true`,
but both logging flags default to `false`; enabling the feature alone writes no
exchange/raw side logs.

| Command | Result |
|---|---|
| `:ParleyToggleExchangeLog` | Toggle `raw_mode.log_exchange`: per-turn message lists in `<chat-dir>/.parley-logs/<basename>/exchange.md` |
| `:ParleyToggleRawLog` | Toggle `raw_mode.log_raw`: request payload, assembled response, and raw SSE in the sibling `raw.md` |
| `:ParleyOpenExchangeLog` | Open the current chat's exchange log in a vertical split |
| `:ParleyOpenRawLog` | Open the current chat's raw log in a vertical split |

When the master switch is false, toggle commands do nothing. Lualine shows red
`LOG-EX` / `LOG-RAW` flags for active logs. Logs contain conversation and request
content, so inspect the relevant turn rather than treating them as ordinary
status messages.

See [raw logging](../infra/raw_logging.md) for format, typed-YAML input, and a
diagnostic guide. Implementation lives in `lua/parley/raw_log.lua`, the commands
in `init.lua`, and indicators in `lualine.lua`; verification is in
`tests/unit/raw_log_spec.lua`.
