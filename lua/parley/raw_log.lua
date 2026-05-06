-- raw_log.lua — Side-file logging for raw_mode debugging.
--
-- Two log files per chat live at:
--   <chat-dir>/.parley-logs/<basename-without-ext>/{exchange,raw}.md
--
-- Each log is append-only; turns are numbered monotonically by counting
-- existing `## Turn ` headers in the file.

local M = {}

local log_emit = require("parley.log_emit")

--- Return the log directory for a given chat file path.
--- `<chat-dir>/.parley-logs/<basename-without-.md>/`
--- @param chat_path string  absolute path to the chat file
--- @return string
function M.log_dir_for(chat_path)
    local dir = vim.fn.fnamemodify(chat_path, ":h")
    local basename = vim.fn.fnamemodify(chat_path, ":t:r")
    return dir .. "/.parley-logs/" .. basename
end

--- Return the absolute path to a specific log file.
--- @param chat_path string
--- @param kind "exchange"|"raw"
--- @return string
function M.log_path_for(chat_path, kind)
    return M.log_dir_for(chat_path) .. "/" .. kind .. ".md"
end

local function ensure_dir(path)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return "" end
    local s = f:read("*a") or ""
    f:close()
    return s
end

local function append_file(path, text)
    local f = io.open(path, "a")
    if not f then
        return false, "could not open " .. path .. " for append"
    end
    f:write(text)
    f:close()
    return true, nil
end

--- Count existing `## Turn ` headers in the file at `path`. Returns 0 for
--- files that don't exist yet.
--- @param path string
--- @return integer
function M.next_turn_number(path)
    local content = read_file(path)
    local count = 0
    for _ in content:gmatch("\n## Turn ") do count = count + 1 end
    -- Also catch the very first turn (no leading newline before the header).
    if content:sub(1, #"## Turn ") == "## Turn " then count = count + 1 end
    return count + 1
end

local function iso_now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function ensure_header(path, kind, basename)
    -- If the file is empty/missing, write the top-level title.
    local content = read_file(path)
    if content == "" then
        ensure_dir(path)
        local title = (kind == "exchange" and "Exchange log for " or "Raw log for ") .. basename
        append_file(path, "# " .. title .. "\n\n")
    end
end

--- Append one exchange-log turn entry to <chat>/exchange.md.
--- @param chat_path string
--- @param messages table  list of { role, content } (content can be string or content-blocks list)
function M.write_exchange_turn(chat_path, messages)
    if not chat_path or chat_path == "" then return end
    local path = M.log_path_for(chat_path, "exchange")
    local basename = vim.fn.fnamemodify(chat_path, ":t:r")
    ensure_header(path, "exchange", basename)
    local turn = M.next_turn_number(path)
    local entry = log_emit.format_exchange_turn({
        turn = turn,
        ts = iso_now(),
        messages = messages,
    })
    append_file(path, entry .. "\n")
end

--- Append one raw-log turn entry to <chat>/raw.md.
--- @param chat_path string
--- @param opts table  { request=table, assembled=table|nil, sse_lines=string[]|nil }
function M.write_raw_turn(chat_path, opts)
    if not chat_path or chat_path == "" then return end
    local path = M.log_path_for(chat_path, "raw")
    local basename = vim.fn.fnamemodify(chat_path, ":t:r")
    ensure_header(path, "raw", basename)
    local turn = M.next_turn_number(path)
    local entry = log_emit.format_raw_turn({
        turn = turn,
        ts = iso_now(),
        request = opts.request,
        assembled = opts.assembled,
        sse_lines = opts.sse_lines,
    })
    append_file(path, entry .. "\n")
end

return M
