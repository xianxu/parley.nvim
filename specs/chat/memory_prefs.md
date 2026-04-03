# Memory Preferences

Per-tag user preference profiles generated from chat history summaries.

## Config
- `memory_prefs.enable`: toggle feature (default: true)
- `memory_prefs.max_summaries`: max summary lines per tag sent to LLM (default: 50)
- `memory_prefs.max_age_days`: re-generate when older than N days (default: 1)
- `memory_prefs.prompt`: LLM prompt for generating preference profiles

## Mechanism
1. **Extract**: single `grep -rn` across all `chat_roots` for `^tags:` and `^📝:` lines
2. **Group**: summaries bucketed by tag (+ `_all` global bucket), sorted chronologically by filename
3. **Summarize**: each bucket sent to current agent's LLM to produce a preference profile
4. **Inject**: on `get_agent_info()`, global + tag-matching preferences appended to system prompt

## Storage
- Preferences JSON at `{chat_dir}/memory_prefs.json`
- Format: `{ last_generated: ISO timestamp, preferences: { tag: text, ... } }`

## Auto-generation
- On `setup()`, if file missing or older than `max_age_days`, triggers async generation
- Uses `mkdir`-based lock (`{state_dir}/memory_prefs.lock/`) — local, not synced for cross-platform atomicity
- Stale locks (>10 min) are automatically cleared

## Command
- `:ParleyMemoryPrefs` — manual trigger (bypasses age check, respects lock)

## Files
- `lua/parley/memory_prefs.lua` — core module
- `lua/parley/config.lua` — config defaults
- `lua/parley/init.lua` — setup, command, system prompt injection
