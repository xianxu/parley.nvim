-- Pre-#81 vanilla Claude baseline fixture metadata
--
-- Captured at Task 1.0 (PRE-M1 prerequisite) per
-- workshop/plans/000081-anthropic-tool-use.md.
--
-- These prompts were run against a vanilla (non-tools) Claude agent on
-- current main BEFORE any #81 code landed, producing the three
-- pre_81_vanilla_claude_request_{1,2,3}.json fixture files alongside
-- this one. M9 Task 9.3 replays the same prompts against the same
-- agent on post-#81 code and diffs the resulting payloads to prove
-- vanilla-chat byte identity.
--
-- Capture provenance:
--   - Date:  2026-04-09
--   - Agent: user's default vanilla Claude agent (claude-sonnet-4-6)
--   - Source cache: ~/.cache/nvim/parley/query/2026-04-09.02-14-*
--
-- IMPORTANT FINDING — server-side tools in the baseline:
-- The captured payloads already contain `tools = [web_search, web_fetch]`
-- because the user's agent has Anthropic's server-side web search enabled.
-- These are NOT parley's client-side tools — they are Anthropic's native
-- server-side tool entries that the existing code path in
-- `lua/parley/providers.lua` already appends. M1 Task 1.5 MUST append
-- client-side tools to this list rather than overwriting it. See the
-- "M1 Task 1.5 server-side-tools preservation" note in issue #81.

return {
  agent_provider = "anthropic",
  agent_model    = "claude-sonnet-4-6",

  -- Prompts in submission order. Each prompt's corresponding payload
  -- fixture captures the REQUEST sent to Anthropic AT THE MOMENT THAT
  -- PROMPT WAS SUBMITTED. So fixture 1 has messages=[prompt1]; fixture 2
  -- has messages=[prompt1, reply1, prompt2]; fixture 3 has the full
  -- 5-message transcript ending in prompt3.
  prompts = {
    "what is 2+2?",
    "Summarize the word 'lua' in one sentence",
    "List three primary colors",
  },

  -- Fixture file names correspond 1:1 to prompts[] by index.
  fixtures = {
    "tests/fixtures/pre_81_vanilla_claude_request_1.json",
    "tests/fixtures/pre_81_vanilla_claude_request_2.json",
    "tests/fixtures/pre_81_vanilla_claude_request_3.json",
  },

  -- Fields that MAY differ across runs due to non-determinism and should
  -- be masked before the M9 diff (e.g., nonces, request IDs). Populate
  -- when M9 builds the diff script and discovers actual variance.
  diff_ignore_fields = {
    -- currently none observed — the request body is stable across runs
  },
}
