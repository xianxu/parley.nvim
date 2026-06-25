-- `chat_history_search` — search this user's saved chat transcripts
-- across all configured chat roots (global + repo-local + super-repo
-- siblings).
--
-- Distinct from the `grep` tool because chat roots routinely live
-- outside cwd (global iCloud dir, sibling super-repo members), so
-- this tool deliberately does not pass any `path` / `file_path`
-- argument through to the dispatcher's cwd-scope guard.
--
-- Backend selection mirrors `grep.lua`: prefer ripgrep, fall back to
-- system grep. Argument surface is structured rather than a raw
-- command string, so we control all flags.

local version = require("parley.tools.version")

local function detect_backend()
    if vim.fn.executable("rg") == 1 then
        local stable = version.stable_command_version(vim.fn.system("rg --version"):match("[^\n]+"), "ripgrep")
        return "rg", stable
    elseif vim.fn.executable("grep") == 1 then
        local stable = version.stable_command_version(vim.fn.system("grep --version 2>&1"):match("[^\n]+"), "grep")
        return "grep", stable
    end
    return nil, nil
end

local backend, backend_version = detect_backend()

local function shell_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function describe()
    local trigger = "Use this whenever the user refers to past chats — phrases like "
        .. "'do you remember when we talked about X', 'what did we discuss about Y', "
        .. "'have we chatted about Z before', 'find past chats on W'. Searches the "
        .. "user's saved chat transcripts (markdown files) across all configured chat "
        .. "roots: global, current repo, and any super-repo siblings. Output paths are "
        .. "prefixed with `{<repo>}/` so you can tell which repo each hit lives in. "
        .. "Default context is -B1 -A2 lines around each match."
    if backend == "rg" then
        return trigger .. " Backend: ripgrep (" .. backend_version .. ")."
    elseif backend == "grep" then
        return trigger .. " Backend: system grep (" .. backend_version .. ")."
    else
        return "Search saved chat transcripts. No grep backend (rg or grep) available."
    end
end

--- For a chat root, compute (anchor, label) used to rewrite output paths.
--- If the dir ends in /workshop/parley, anchor at the parent (repo root) so
--- the rendered path becomes `{repo_basename}/workshop/parley/<file>`.
--- Otherwise anchor at the dir itself (e.g. global iCloud dir).
local function compute_anchor(root)
    local dir = root.dir
    local repo_suffix = "/workshop/parley"
    if dir:sub(-#repo_suffix) == repo_suffix then
        local parent = dir:sub(1, -#repo_suffix - 1)
        local name = vim.fn.fnamemodify(parent, ":t")
        return parent, name ~= "" and name or root.label or "repo"
    end
    return dir, root.label or vim.fn.fnamemodify(dir, ":t")
end

--- Replace the leading absolute anchor in each rg/grep line with `{label}/`.
--- rg/grep with -n emit "<path>:<line>:<text>". Strip the anchor prefix from
--- <path> and prepend the label marker.
local function rewrite_paths(output, anchor, label)
    local prefix = anchor:gsub("/+$", "") .. "/"
    local marker = "{" .. label .. "}/"
    local out = {}
    for line in (output .. "\n"):gmatch("([^\n]*)\n") do
        if line == "" then
            -- preserve blank lines (rg's separator between match groups)
            table.insert(out, line)
        elseif line == "--" then
            table.insert(out, line)
        else
            local rewritten = line
            if line:sub(1, #prefix) == prefix then
                rewritten = marker .. line:sub(#prefix + 1)
            end
            table.insert(out, rewritten)
        end
    end
    -- drop trailing empty entry from the gmatch trick
    if out[#out] == "" then table.remove(out) end
    return table.concat(out, "\n")
end

local function build_cmd(input, root_dir)
    local pattern = input.pattern
    local before = input.before or 1
    local after = input.after or 2
    local case_insensitive = input.case_insensitive
    if case_insensitive == nil then case_insensitive = true end
    local glob = input.glob or "*.md"
    local max_count = input.max_count

    if backend == "rg" then
        local parts = { "rg", "--line-number", "--with-filename", "--no-heading",
                        "-B", tostring(before), "-A", tostring(after),
                        "--glob", shell_quote(glob) }
        if case_insensitive then table.insert(parts, "-i") end
        if max_count then table.insert(parts, "-m"); table.insert(parts, tostring(max_count)) end
        table.insert(parts, "--")
        table.insert(parts, shell_quote(pattern))
        table.insert(parts, shell_quote(root_dir))
        return table.concat(parts, " ")
    else
        -- system grep
        local parts = { "grep", "-rn", "-B", tostring(before), "-A", tostring(after),
                        "--include=" .. shell_quote(glob) }
        if case_insensitive then table.insert(parts, "-i") end
        if max_count then table.insert(parts, "-m"); table.insert(parts, tostring(max_count)) end
        table.insert(parts, "-E")
        table.insert(parts, "--")
        table.insert(parts, shell_quote(pattern))
        table.insert(parts, shell_quote(root_dir))
        return table.concat(parts, " ")
    end
end

local function search_root(input, root)
    local anchor, label = compute_anchor(root)
    if vim.fn.isdirectory(root.dir) ~= 1 then
        return nil
    end
    local cmd = build_cmd(input, root.dir)
    local result = vim.fn.system(cmd)
    local exit_code = vim.v.shell_error
    -- 0 = matches, 1 = no matches, 2+ = error (both rg and grep)
    if exit_code >= 2 then
        return {
            label = label,
            error = (backend or "grep") .. " error (exit " .. exit_code .. "): " .. (result or ""),
        }
    end
    local trimmed = (result or ""):gsub("%s+$", "")
    if trimmed == "" then
        return { label = label, content = nil }
    end
    return { label = label, content = rewrite_paths(trimmed, anchor, label) }
end

return {
    name = "chat_history_search",
    kind = "read",
    description = describe(),
    input_schema = {
        type = "object",
        properties = {
            pattern = {
                type = "string",
                description = "Regex pattern to search for. Required.",
            },
            before = {
                type = "integer",
                description = "Lines of context before each match. Default: 1.",
            },
            after = {
                type = "integer",
                description = "Lines of context after each match. Default: 2.",
            },
            glob = {
                type = "string",
                description = "File glob filter. Default: '*.md'.",
            },
            case_insensitive = {
                type = "boolean",
                description = "Case-insensitive match. Default: true.",
            },
            max_count = {
                type = "integer",
                description = "Maximum matches per file. Optional.",
            },
        },
        required = { "pattern" },
    },
    handler = function(input)
        input = input or {}
        if type(input.pattern) ~= "string" or input.pattern == "" then
            return {
                content = "missing or invalid required field: pattern",
                is_error = true,
                name = "chat_history_search",
            }
        end
        if not backend then
            return {
                content = "no grep backend available on this system (neither rg nor grep found)",
                is_error = true,
                name = "chat_history_search",
            }
        end

        local ok, parley = pcall(require, "parley")
        if not ok or type(parley.get_chat_roots) ~= "function" then
            return {
                content = "parley.get_chat_roots() unavailable — is parley.setup() complete?",
                is_error = true,
                name = "chat_history_search",
            }
        end

        local roots = parley.get_chat_roots() or {}
        if #roots == 0 then
            return {
                content = "no chat roots configured",
                is_error = true,
                name = "chat_history_search",
            }
        end

        local sections = {}
        local any_hits = false
        for _, root in ipairs(roots) do
            local r = search_root(input, root)
            if r then
                if r.error then
                    table.insert(sections, "── {" .. r.label .. "} ──\n" .. r.error)
                elseif r.content then
                    any_hits = true
                    table.insert(sections, "── {" .. r.label .. "} ──\n" .. r.content)
                end
            end
        end

        if not any_hits and #sections == 0 then
            return {
                content = "no matches found across " .. #roots .. " chat root(s)",
                is_error = false,
                name = "chat_history_search",
            }
        end

        return {
            content = table.concat(sections, "\n\n"),
            is_error = false,
            name = "chat_history_search",
        }
    end,
}
