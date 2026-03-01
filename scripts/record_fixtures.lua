-- scripts/record_fixtures.lua
--
-- Records real SSE response fixture files from LLM APIs for use in tests.
-- Committed fixtures go stale only if the API wire format changes; re-run this
-- script when that happens.
--
-- Usage (two options):
--   1. From terminal (headless Neovim):
--        make fixtures
--      or directly:
--        ANTHROPIC_API_KEY=sk-... OPENAI_API_KEY=sk-... \
--          nvim --headless --noplugin -u tests/minimal_init.vim \
--          -c "luafile scripts/record_fixtures.lua" -c "qa!"
--
--   2. From inside Neovim (with API keys already in environment):
--        :luafile scripts/record_fixtures.lua

local fixtures_dir = "tests/fixtures"
vim.fn.mkdir(fixtures_dir, "p")

-- Run a shell command and return stdout as a string.
local function capture(cmd)
    local handle = io.popen(cmd .. " 2>/dev/null")
    if not handle then return nil, "failed to open pipe" end
    local out = handle:read("*a")
    handle:close()
    return out
end

-- Write content to a file and print a summary line.
local function write_fixture(name, content)
    if not content or #content == 0 then
        print("  SKIP " .. name .. " (empty response — check your API key)")
        return
    end
    local path = fixtures_dir .. "/" .. name
    local f = io.open(path, "w")
    if not f then
        print("  ERROR could not write " .. path)
        return
    end
    f:write(content)
    f:close()
    print("  OK   " .. path .. " (" .. #content .. " bytes)")
end

print("=== Recording SSE fixtures ===")
print("Fixtures dir: " .. fixtures_dir)
print("")

-- ─── Anthropic ────────────────────────────────────────────────────────────────

local anthropic_key = os.getenv("ANTHROPIC_API_KEY") or ""

if anthropic_key == "" then
    print("ANTHROPIC_API_KEY not set — skipping Anthropic fixtures")
else
    print("Recording Anthropic fixtures...")

    -- Basic stream (claude-haiku, short answer)
    local cmd = table.concat({
        "curl https://api.anthropic.com/v1/messages",
        "-H 'x-api-key: " .. anthropic_key .. "'",
        "-H 'anthropic-version: 2023-06-01'",
        "-H 'anthropic-beta: messages-2023-12-15'",
        "-H 'content-type: application/json'",
        "--no-buffer -s",
        "-d '{\"model\":\"claude-haiku-20240307\",\"stream\":true,\"max_tokens\":40,"
            .. "\"messages\":[{\"role\":\"user\",\"content\":\"Say: hello world\"}]}'"
    }, " ")
    write_fixture("anthropic_stream.txt", capture(cmd))

    -- Error response (bad model name — no real request needed, craft one)
    -- We record this as a static fixture rather than making a real bad request.
    local error_content = table.concat({
        'event: error',
        'data: {"type":"error","error":{"type":"invalid_request_error","message":"model: field required"}}',
        '',
    }, "\n")
    write_fixture("anthropic_error.txt", error_content)
end

-- ─── OpenAI ───────────────────────────────────────────────────────────────────

local openai_key = os.getenv("OPENAI_API_KEY") or ""

if openai_key == "" then
    print("OPENAI_API_KEY not set — skipping OpenAI fixtures")
else
    print("Recording OpenAI fixtures...")

    -- Basic stream (gpt-4o-mini, short answer, with usage chunk)
    local cmd = table.concat({
        "curl https://api.openai.com/v1/chat/completions",
        "-H 'Authorization: Bearer " .. openai_key .. "'",
        "-H 'content-type: application/json'",
        "--no-buffer -s",
        "-d '{\"model\":\"gpt-4o-mini\",\"stream\":true,\"max_tokens\":40,"
            .. "\"stream_options\":{\"include_usage\":true},"
            .. "\"messages\":[{\"role\":\"user\",\"content\":\"Say: hello world\"}]}'"
    }, " ")
    write_fixture("openai_stream.txt", capture(cmd))
end

-- ─── Google AI ────────────────────────────────────────────────────────────────

local googleai_key = os.getenv("GOOGLEAI_API_KEY") or ""

if googleai_key == "" then
    print("GOOGLEAI_API_KEY not set — skipping Google AI fixtures")
else
    print("Recording Google AI fixtures...")

    local model = "gemini-2.0-flash"
    local endpoint = "https://generativelanguage.googleapis.com/v1beta/models/"
        .. model .. ":streamGenerateContent?key=" .. googleai_key

    local cmd = table.concat({
        "curl '" .. endpoint .. "'",
        "-H 'content-type: application/json'",
        "--no-buffer -s",
        "-d '{\"contents\":[{\"role\":\"user\",\"parts\":[{\"text\":\"Say: hello world\"}]}],"
            .. "\"generationConfig\":{\"maxOutputTokens\":40}}'"
    }, " ")
    write_fixture("googleai_stream.txt", capture(cmd))
end

print("")
print("=== Done. Commit tests/fixtures/ to keep them fresh. ===")
print("Re-run with: make fixtures")
