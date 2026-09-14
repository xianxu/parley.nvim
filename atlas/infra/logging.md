# Logging and troubleshooting

Use `:checkhealth parley` for missing dependencies, `:ParleyInspectLog` for the
runtime log, and `:ParleyInspectPlugin` to inspect the current plugin state.
The latter two are default hooks and can be replaced through configuration.

`log_file` defaults to Neovim's log directory plus `parley.nvim.log`; the app
uses its state directory's `parley.log`. Levels are TRACE, DEBUG, INFO, WARNING
and ERROR. On setup, files over 20,000 lines are reduced to their last 10,000.

`log_sensitive` defaults to `false`. Messages explicitly marked sensitive are
replaced with `REDACTED` in this log unless enabled; this is not automatic scanning
or redaction of arbitrary text. Inspect diagnostics before sharing them.

For questions about what the model received or returned, use the separate
[exchange/raw logs](raw_logging.md). Those capture request/conversation content
when enabled and are not controlled by `log_sensitive`.

Implementation: `lua/parley/logger.lua`, the inspection hooks in `config.lua`,
and `starter_config.lua`. Coverage: `tests/unit/logger_spec.lua` and
`tests/arch/log_sinks_spec.lua`.
