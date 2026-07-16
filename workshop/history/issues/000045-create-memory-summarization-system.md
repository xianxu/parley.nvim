---
id: 000045
status: done
deps: []
created: 2026-03-31
updated: 2026-04-03
---

# create memory summarization system

All the chats are in local drive, it's very easy to create memory summarization, so parley becomes personal. Chats have tags, so we can summarized for each [tag] and overall. 

The memory system aim to keep a per tag user preference based on past chat history. To get summary (level 1) of past chat, we can just grep lines starting with 📝 for some glaces of what is discussed (with 📝 removed). For chats without such lines, we will just have empty summary lines. So we have:

[] [tag1] [tag2] summary line 1
[] [tag1] [tag2] summary line 2
[] [tag1] summary line 3

[] here is a placeholder. those liens should be sorted based on last modify time.

then we do a map reduce to generate for each tag the summary lines:

[] summary line 1
[] summary line 2
[] summary line 3
[tag1] summary line 1
[tag1] summary line 2
[tag1] summary line 3
[tag2] summary line 1
[tag2] summary line 2

Then, for each tag, we pick last N lines, then send to LLM to generate a user preference string. so:

[] LLM(["summary line 1", "summary line 2", "summary line 3"])
[tag1] LLM(["summary line 1", "summary line 2", "summary line 3"])
[tag2] LLM(["summary line 1", "summary line 2"])

Use the following prompt to generate: "Based on user chat history, generate a concise user preference profile that is suited to be used for Claude/ChatGPT's system prompt"

then such user preference is stored in a file. 

The generated additional "preference prompt" would be appended to system prompt, based on the tags of a chat. 

We are into how do we organize system_prompt territory. The current structure is simple, just a string. but in the future, there should be:

1. "structural prompt": e.g. as LLM to generate 🧠:, 📝: lines.
2. "user preference": e.g. what user may initially put in. 
3. "discovered user preference": based on above memory mechanism.

In parley, for now 1 and 2 are modeled as system_prompt. and 3 is what we described above.

## Done when

-

## Plan

- [x] Create `lua/parley/memory_prefs.lua` — core module (extract, summarize, load, inject)
- [x] Add `memory_prefs` config to `lua/parley/config.lua`
- [x] Integrate in `lua/parley/init.lua` — setup, command, system prompt injection
- [x] Create spec `specs/chat/memory_prefs.md`
- [x] Update `specs/index.md`
- [x] Lint + test (all pass, 6 new unit tests)

## Log

### 2026-04-03
- Created `lua/parley/memory_prefs.lua` — extracts 📝 summaries via grep, groups by tag, sends to LLM for preference generation, injects into system prompt
- Per-tag markdown files (`memory_prefs_{tag}.md`) stored in chat_dir (syncs via iCloud)
- Auto-generates on startup if files missing or stale (>1 day), in-memory lock prevents concurrent runs
- Refactored pure functions: `parse_grep_output`, `build_grep_cmd`, `parse_tag_content`, `is_stale`
- 15 unit tests covering all pure functions
- Also refactored `.openshell/sandbox.sh` mutagen sync setup (extracted `ensure_sync` helper, `SYNC_NAMES` list, `terminate_all_syncs`)
- Added nvim state dir sync to sandbox for log access

