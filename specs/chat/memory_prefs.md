# Memory Preferences

Per-tag user preference profiles generated from chat history summaries.

## Config
- `memory_prefs.enable`: toggle feature (default: true)
- `memory_prefs.max_files`: max recent chat files per tag to include summaries from (default: 100)
- `memory_prefs.max_age_days`: re-generate when older than N days (default: 1)
- `memory_prefs.prompt`: LLM prompt for generating preference profiles

## Mechanism
1. **Extract**: single `grep -rn` across all `chat_roots` for `^tags:` and `^📝:` lines
2. **Group**: summaries bucketed by tag (+ `_all` global bucket), sorted chronologically by filename
3. **Summarize**: each bucket sent to current agent's LLM to produce a preference profile
4. **Inject**: on `get_agent_info()`, global + tag-matching preferences appended to system prompt

## Storage
- One markdown file per tag at `{chat_dir}/memory_prefs_{tag}.md`
- Each file has an HTML comment timestamp (`<!-- last_generated: ISO -->`) followed by the preference text
- In-memory cache invalidated on save; reloaded from disk on next `load()`

## Auto-generation
- On `setup()`, if files missing or oldest is older than `max_age_days`, triggers async generation after 2s delay
- In-memory boolean lock prevents concurrent generation within the same session

## Command
- `:ParleyMemoryPrefs` — manual trigger (bypasses age check, respects lock)

## Files
- `lua/parley/memory_prefs.lua` — core module
- `lua/parley/config.lua` — config defaults
- `lua/parley/init.lua` — setup, command, system prompt injection
