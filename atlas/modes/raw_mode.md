# Raw Mode

Per-chat side-file logging of API state for debugging and learning. Replaces the previous in-buffer behavior (#121).

**For agents debugging parley:** this is the first-line diagnostic tool for any LLM-pipeline issue (wrong prompt, missing messages, cache misses, tool_use shape, token usage, SSE oddities). Toggle on, reproduce, inspect the side files, toggle off. See [`atlas/infra/raw_logging.md`](../infra/raw_logging.md#when-to-use-this-debugging-entry-point) for the decision tree (exchange-level vs raw-API-level) and the full spec — file layout, format, toggles, lualine indicator, and the typed-YAML input feature.

Quick reference:

- `raw_mode.enable` — master switch (default `true`).
- `raw_mode.log_exchange` — per-turn message-list log to `<chat-dir>/.parley-logs/<basename>/exchange.md`.
- `raw_mode.log_raw` — per-turn request payload + assembled response + raw SSE log to `…/raw.md`.
- `:ParleyToggleExchangeLog`, `:ParleyToggleRawLog` — flip the toggles.
- `:ParleyOpenExchangeLog`, `:ParleyOpenRawLog` — open the current chat's log in a vsplit.
- A red `[LOG-EX]` / `[LOG-RAW]` flag appears in the lualine parley section while a toggle is on.
