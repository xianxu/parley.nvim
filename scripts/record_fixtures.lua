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

local has_errors = false

-- Run a shell command and return stdout as a string.
local function capture(cmd)
    local handle = io.popen(cmd .. " 2>/dev/null")
    if not handle then return nil, "failed to open pipe" end
    local out = handle:read("*a")
    handle:close()
    return out
end

-- Check if response contains an error
local function is_error_response(content)
    if not content or #content == 0 then
        return true, "empty response"
    end
    -- Check for error patterns in JSON responses
    if content:find('"type"%s*:%s*"error"') or 
       content:find('"error"%s*:%s*{') then
        return true, "API returned error"
    end
    return false, nil
end

-- Write content to a file and print a summary line.
-- Returns true if successful, false if error.
local function write_fixture(name, content, expect_error)
    if not content or #content == 0 then
        print("  FAIL " .. name .. " (empty response — check your API key)")
        has_errors = true
        return false
    end
    
    local is_err, err_msg = is_error_response(content)
    
    -- For non-error fixtures, fail if we got an error response
    if not expect_error and is_err then
        print("  FAIL " .. name .. " (" .. err_msg .. ")")
        print("       Response: " .. content:sub(1, 200))
        has_errors = true
        return false
    end
    
    -- For error fixtures, it's OK to have an error
    -- (but we still write it)
    
    local path = fixtures_dir .. "/" .. name
    local f = io.open(path, "w")
    if not f then
        print("  FAIL could not write " .. path)
        has_errors = true
        return false
    end
    f:write(content)
    f:close()
    
    if expect_error then
        print("  OK   " .. path .. " (error fixture, " .. #content .. " bytes)")
    else
        print("  OK   " .. path .. " (" .. #content .. " bytes)")
    end
    return true
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

    -- Basic stream (claude-sonnet-4, short answer)
    local cmd = table.concat({
        "curl https://api.anthropic.com/v1/messages",
        "-H 'x-api-key: " .. anthropic_key .. "'",
        "-H 'anthropic-version: 2023-06-01'",
        "-H 'anthropic-beta: messages-2023-12-15'",
        "-H 'content-type: application/json'",
        "--no-buffer -s",
        "-d '{\"model\":\"claude-sonnet-4-20250514\",\"stream\":true,\"max_tokens\":40,"
            .. "\"messages\":[{\"role\":\"user\",\"content\":\"Say: hello world\"}]}'"
    }, " ")
    write_fixture("anthropic_stream.txt", capture(cmd))

    -- Error response (intentionally use a bad model name to get real error format)
    local error_cmd = table.concat({
        "curl https://api.anthropic.com/v1/messages",
        "-H 'x-api-key: " .. anthropic_key .. "'",
        "-H 'anthropic-version: 2023-06-01'",
        "-H 'content-type: application/json'",
        "--no-buffer -s",
        "-d '{\"model\":\"invalid-model-name\",\"stream\":true,\"max_tokens\":10,"
            .. "\"messages\":[{\"role\":\"user\",\"content\":\"test\"}]}'"
    }, " ")
    write_fixture("anthropic_error.txt", capture(error_cmd), true) -- expect_error=true
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
    
    -- Error response (intentionally use bad model name)
    local error_cmd = table.concat({
        "curl https://api.openai.com/v1/chat/completions",
        "-H 'Authorization: Bearer " .. openai_key .. "'",
        "-H 'content-type: application/json'",
        "--no-buffer -s",
        "-d '{\"model\":\"invalid-model-name\",\"stream\":true,\"max_tokens\":10,"
            .. "\"messages\":[{\"role\":\"user\",\"content\":\"test\"}]}'"
    }, " ")
    write_fixture("openai_error.txt", capture(error_cmd), true) -- expect_error=true
end

-- ─── Google AI ────────────────────────────────────────────────────────────────

local googleai_key = os.getenv("GOOGLEAI_API_KEY") or ""

if googleai_key == "" then
    print("GOOGLEAI_API_KEY not set — skipping Google AI fixtures")
else
    print("Recording Google AI fixtures...")

    local model = "gemini-2.5-flash"
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
    
    -- Error response (use invalid model name)
    local error_model = "invalid-model-name"
    local error_endpoint = "https://generativelanguage.googleapis.com/v1beta/models/"
        .. error_model .. ":streamGenerateContent?key=" .. googleai_key
    
    local error_cmd = table.concat({
        "curl '" .. error_endpoint .. "'",
        "-H 'content-type: application/json'",
        "--no-buffer -s",
        "-d '{\"contents\":[{\"role\":\"user\",\"parts\":[{\"text\":\"test\"}]}]}'"
    }, " ")
    write_fixture("googleai_error.txt", capture(error_cmd), true) -- expect_error=true
end

print("")
if has_errors then
    print("=== FAILED: Some fixtures had errors ===")
    print("Check your API keys and try again.")
    print("Re-run with: make fixtures")
    os.exit(1)
else
    print("=== Done. Commit tests/fixtures/ to keep them fresh. ===")
    print("Re-run with: make fixtures")
    os.exit(0)
end
