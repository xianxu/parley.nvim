-- `ack` — shell out to the local `ack` command (if installed).
--
-- Only registered if ack is available. The tool description advertises
-- the version so Claude adapts its syntax.

local argv = require("parley.tools.builtin.argv")

local ALLOWED_FIELDS = {
    pattern = true,
    path = true,
    paths = true,
    ignore_case = true,
    type = true,
    context = true,
    context_before = true,
    context_after = true,
}

local function detect_ack()
    if vim.fn.executable("ack") == 1 then
        local version = vim.fn.system({ "ack", "--version" }):match("[^\n]+") or "ack"
        return "ack", version
    end
    return nil, nil
end

local ack_cmd, ack_version = detect_ack()

local function build_description()
    if ack_cmd then
        return "Search file contents using ack (" .. ack_version .. "). "
            .. "ack is a grep-like tool optimized for source code. "
            .. "Use structured fields: pattern, path or paths, type, ignore_case, "
            .. "and context/context_before/context_after. "
            .. "Pattern and paths are passed as argv data, not shell text. "
            .. "Paths are confined to the working directory/read roots."
    else
        return "Search file contents using ack. Not available on this system."
    end
end

local function fail(message)
    return {
        content = message,
        is_error = true,
        name = "ack",
    }
end

local function add_count_option(cmd, flag, value, name)
    local n, err = argv.nonnegative_int(value, name)
    if err then
        return nil, err
    end
    if n ~= nil then
        cmd[#cmd + 1] = flag
        cmd[#cmd + 1] = tostring(n)
    end
    return true
end

local function build_command(input)
    local ok, err = argv.reject_unknown_fields(input, ALLOWED_FIELDS)
    if not ok then
        return nil, err
    end

    if type(input.pattern) ~= "string" or input.pattern == "" then
        return nil, "missing or invalid required field: pattern"
    end

    if input.ignore_case ~= nil and type(input.ignore_case) ~= "boolean" then
        return nil, "ignore_case must be boolean"
    end

    local cmd = { ack_cmd }
    if input.ignore_case then
        cmd[#cmd + 1] = "-i"
    end

    if input.type ~= nil then
        if type(input.type) ~= "string" or not input.type:match("^[%w_-]+$") then
            return nil, "type must contain only letters, numbers, underscores, or hyphens"
        end
        cmd[#cmd + 1] = "--type=" .. input.type
    end

    ok, err = add_count_option(cmd, "-C", input.context, "context")
    if not ok then
        return nil, err
    end
    ok, err = add_count_option(cmd, "-B", input.context_before, "context_before")
    if not ok then
        return nil, err
    end
    ok, err = add_count_option(cmd, "-A", input.context_after, "context_after")
    if not ok then
        return nil, err
    end

    cmd[#cmd + 1] = "--"
    cmd[#cmd + 1] = input.pattern

    ok, err = argv.append_path_args(cmd, input.paths or input.path or ".")
    if not ok then
        return nil, err
    end

    return cmd
end

return {
    name = "ack",
    kind = "read",
    default_path = ".",
    -- Mark as unavailable when ack is not installed so the tool
    -- registry can skip it.
    available = ack_cmd ~= nil,
    description = build_description(),
    input_schema = {
        type = "object",
        properties = {
            pattern = {
                type = "string",
                description = "Perl-compatible regex pattern to search for.",
            },
            path = {
                type = "string",
                description = "File or directory to search. Defaults to the working directory.",
            },
            paths = {
                type = "array",
                items = { type = "string" },
                description = "Files or directories to search. Overrides path when present.",
            },
            type = {
                type = "string",
                description = "ack file type filter, e.g. lua or python.",
            },
            ignore_case = {
                type = "boolean",
                description = "Run a case-insensitive search.",
            },
            context = {
                type = "integer",
                minimum = 0,
                description = "Show this many context lines before and after each match.",
            },
            context_before = {
                type = "integer",
                minimum = 0,
                description = "Show this many lines before each match.",
            },
            context_after = {
                type = "integer",
                minimum = 0,
                description = "Show this many lines after each match.",
            },
        },
        required = { "pattern" },
    },
    handler = function(input)
        input = input or {}
        if not ack_cmd then
            return fail("ack is not installed on this system. Use grep instead.")
        end

        local cmd, err = build_command(input)
        if not cmd then
            return fail(err)
        end

        local result = vim.fn.system(cmd)
        local exit_code = vim.v.shell_error

        -- ack: 0=matches, 1=no matches, 2+=error
        if exit_code >= 2 then
            return {
                content = "ack error (exit " .. exit_code .. "):\n" .. (result or ""),
                is_error = true,
                name = "ack",
            }
        end

        local trimmed = (result or ""):gsub("%s+$", "")
        if trimmed == "" then
            return {
                content = "no matches found",
                is_error = false,
                name = "ack",
            }
        end

        return {
            content = trimmed,
            is_error = false,
            name = "ack",
        }
    end,
}
