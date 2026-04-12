-- Offline payload builder for parley transcripts.
-- Used by scripts/test-anthropic-interaction.sh and unit tests.
--
-- Usage from Lua:
--   local payload = require("scripts.parley_harness").build_payload("path/to/transcript.md")
--   local payload = require("scripts.parley_harness").build_payload(path, { agent_name = "ToolSonnet" })
--
-- Usage from shell (via the .sh wrapper):
--   PARLEY_HARNESS_DRY_RUN=1 scripts/test-anthropic-interaction.sh transcript.md
--   PARLEY_HARNESS_AGENT=ToolSonnet scripts/test-anthropic-interaction.sh transcript.md
--
-- See docs/plans/000090-renderer-refactor.md section 6.

local M = {}

local function load_lines(path)
    local f = assert(io.open(path, "r"), "cannot open transcript: " .. path)
    local lines = {}
    for line in f:lines() do
        table.insert(lines, line)
    end
    f:close()
    return lines
end

local function ensure_parley_setup()
    local parley = require("parley")
    if not parley._state or not parley._state.agent then
        parley.setup({
            chat_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-harness",
            state_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-harness/state",
            providers = {},
            api_keys = {},
        })
    end
    return parley
end

--- Build the Anthropic payload that would be sent for the LAST exchange
--- in the transcript. Mirrors the chat_respond → dispatcher path.
---
--- @param transcript_path string
--- @param opts table|nil { agent_name = string }
--- @return table payload
function M.build_payload(transcript_path, opts)
    opts = opts or {}
    local parley = ensure_parley_setup()

    local lines = load_lines(transcript_path)
    local chat_parser = require("parley.chat_parser")
    local cfg = require("parley.config")
    local header_end = chat_parser.find_header_end(lines)
    local parsed = chat_parser.parse_chat(lines, header_end, cfg)

    local exchange_idx = #parsed.exchanges
    assert(exchange_idx > 0, "transcript has no exchanges: " .. transcript_path)

    -- Resolve the agent. Precedence:
    --   1. opts.agent_name (programmatic override)
    --   2. PARLEY_HARNESS_AGENT env var
    --   3. parley default state agent
    local agent_name = opts.agent_name or os.getenv("PARLEY_HARNESS_AGENT")
    local agent = parley.get_agent(agent_name)
    local agent_info = parley.get_agent_info(parsed.headers, agent)

    local messages = parley._build_messages({
        parsed_chat = parsed,
        start_index = 1,
        end_index = #lines,
        exchange_idx = exchange_idx,
        agent = agent_info,
        config = cfg,
        helpers = require("parley.helper"),
        logger = { debug = function() end, warning = function() end },
    })

    local dispatcher = require("parley.dispatcher")
    local payload = dispatcher.prepare_payload(messages, agent_info.model, agent_info.provider, agent_info.tools)
    return payload
end

--- CLI entry point — called from the shell wrapper.
function M.run(transcript_path)
    local payload = M.build_payload(transcript_path)
    local json = vim.json.encode(payload)

    -- Pretty-print via python3 if available
    local pretty = vim.fn.system({ "python3", "-m", "json.tool" }, json)
    if vim.v.shell_error == 0 and pretty and pretty ~= "" then
        json = pretty
    end

    if os.getenv("PARLEY_HARNESS_DRY_RUN") == "1" then
        io.stdout:write("=== PAYLOAD (dry run) ===\n")
        io.stdout:write(json)
        io.stdout:write("\n")
        return
    end

    local key = os.getenv("ANTHROPIC_API_KEY")
    if not key or key == "" then
        io.stderr:write("ANTHROPIC_API_KEY not set; use PARLEY_HARNESS_DRY_RUN=1 for offline mode\n")
        os.exit(1)
    end

    -- Write payload to a temp file and curl it
    local tmpfile = vim.fn.tempname() .. ".json"
    local f = assert(io.open(tmpfile, "w"))
    f:write(json)
    f:close()

    local cmd = {
        "curl", "-s", "-w", "\nHTTP %{http_code}\n",
        "https://api.anthropic.com/v1/messages",
        "-H", "Content-Type: application/json",
        "-H", "x-api-key: " .. key,
        "-H", "anthropic-version: 2023-06-01",
        "-d", "@" .. tmpfile,
    }
    local out = vim.fn.system(cmd)
    io.stdout:write("=== PAYLOAD ===\n" .. json .. "\n=== RESPONSE ===\n" .. out .. "\n")
    os.remove(tmpfile)
end

return M
